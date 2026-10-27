using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Xepa.Application.Pagamentos;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Pedidos;

/// <summary>
/// Corrida oferecida ao entregador, como nos apps de delivery: quanto paga, quantos km até a coleta e da coleta
/// ao cliente. Antes de aceitar ele vê só o bairro do destino; depois, o endereço completo e o nome do cliente.
/// </summary>
public record CorridaDto(int PedidoId, StatusPedido Status, decimal Valor, string Loja, string EnderecoColeta, Coordenada? Coleta,
    string BairroDestino, string? EnderecoDestino, Coordenada? Destino, string? Cliente, double? DistanciaAteColetaKm,
    double DistanciaEntregaKm, double DistanciaTotalKm, int MinutosEstimados, int Quantidade, string Oferta, string? Observacao,
    bool Minha, bool Coletada);

public record GanhosDto(int CorridasHoje, decimal GanhosHoje, double KmHoje, int CorridasSemana, decimal GanhosSemana,
    double KmSemana, int CorridasMes, decimal GanhosMes, double KmMes, int CorridasTotal, decimal GanhosTotal,
    IReadOnlyList<GanhoDiaDto> UltimosDias, IReadOnlyList<CorridaFeitaDto> Corridas);

/// <summary>Ganho de um dia (horário de Brasília), para o gráfico dos últimos 7 dias.</summary>
public record GanhoDiaDto(DateOnly Dia, decimal Valor, int Corridas);

/// <summary>Corrida já entregue, com a nota que o cliente deu (se deu).</summary>
public record CorridaFeitaDto(int PedidoId, DateTimeOffset EntregueEm, string Loja, string Bairro, decimal Valor, double Km,
    int? Nota, string? Comentario);

public record AvaliacaoEntregadorDto(int Nota, string? Comentario, string Cliente, DateTimeOffset Em);

/// <summary>Perfil do entregador parceiro: dados da moto, preferências e a reputação dada pelos clientes.</summary>
public record PerfilEntregadorDto(string Nome, string Email, string? Telefone, string? Placa, string? ModeloMoto, bool Online,
    int RaioCorridasKm, double? Nota, int Avaliacoes, IReadOnlyList<int> Estrelas, int CorridasTotal, DateTimeOffset MembroDesde,
    IReadOnlyList<AvaliacaoEntregadorDto> UltimasAvaliacoes);

public class AtualizarPerfilEntregadorRequest
{
    [Required(ErrorMessage = "Informe seu nome."), MaxLength(120)]
    public required string Nome { get; init; }

    [Required(ErrorMessage = "Informe o telefone."), Phone(ErrorMessage = "Telefone inválido."), MaxLength(20)]
    public required string Telefone { get; init; }

    [Required(ErrorMessage = "Informe a placa da moto."),
     RegularExpression(@"^[A-Za-z]{3}-?\d[A-Za-z\d]\d{2}$", ErrorMessage = "Placa inválida (ex.: ABC1D23).")]
    public required string Placa { get; init; }

    [MaxLength(60)]
    public string? ModeloMoto { get; init; }

    [Range(1, EntregaService.RaioOfertaKm, ErrorMessage = "O raio vai de 1 a 15 km.")]
    public int RaioCorridasKm { get; init; } = 8;
}

/// <summary>Traçados para o mapa do entregador: até a loja (antes de coletar) e da loja ao cliente.</summary>
public record RotaCorridaDto(IReadOnlyList<Coordenada>? AteColeta, IReadOnlyList<Coordenada>? Entrega, double? DistanciaAteColetaKm,
    double DistanciaEntregaKm, int MinutosEstimados);

/// <summary>
/// Entregadores parceiros da XEPA: veem as corridas perto deles, aceitam, coletam na loja e entregam com o código
/// do cliente. A taxa de entrega paga pelo cliente vai inteira para o entregador.
/// </summary>
public class EntregaService(IXepaDb db, IServicoMapas mapas, INotificadorPedidos notificador)
{
    /// <summary>Raio máximo que o entregador pode escolher para ver corridas (pela loja de coleta).</summary>
    public const int RaioOfertaKm = 15;

    /// <summary>Velocidade média de moto na cidade, para estimar o tempo quando não há rota calculada.</summary>
    private const double VelocidadeMotoKmH = 25;

    /// <summary>A corrida pode ser aceita desde que a loja aceita o pedido até ela marcar pronto.</summary>
    private static readonly StatusPedido[] StatusDisponivel = [StatusPedido.Confirmado, StatusPedido.EmPreparo, StatusPedido.ProntoParaRetirada];

    /// <summary>
    /// Corridas disponíveis dentro do raio escolhido pelo entregador, mais a que já está com ele. Offline, ele só vê a dele.
    /// </summary>
    public async Task<IReadOnlyList<CorridaDto>> ListarAsync(int entregadorId, Coordenada? posicao, CancellationToken ct)
    {
        var eu = await db.Usuarios.AsNoTracking().Where(u => u.Id == entregadorId)
            .Select(u => new { u.Online, u.RaioCorridasKm }).FirstAsync(ct);

        var pedidos = await db.Pedidos.AsNoTracking()
            .Where(p => p.TipoEntrega == TipoEntrega.Entrega
                        && ((eu.Online && p.EntregadorId == null && p.ClienteId != entregadorId && StatusDisponivel.Contains(p.Status))
                            || (p.EntregadorId == entregadorId
                                && (StatusDisponivel.Contains(p.Status) || p.Status == StatusPedido.SaiuParaEntrega))))
            .OrderBy(p => p.CriadoEm)
            .Select(p => new
            {
                p.Id, p.Status, p.TaxaEntrega, p.DistanciaEntregaKm, p.EntregadorId, p.Quantidade, p.Observacao,
                Loja = p.Oferta.Estabelecimento.Nome, Coleta = p.Oferta.Estabelecimento.Endereco,
                Oferta = p.Oferta.Titulo, Cliente = p.Cliente.Nome, p.EnderecoEntrega
            })
            .ToListAsync(ct);

        var corridas = pedidos.Select(p =>
            {
                var minha = p.EntregadorId == entregadorId;
                var coleta = Ponto(p.Coleta);
                var destino = p.EnderecoEntrega is null ? null : Ponto(p.EnderecoEntrega);
                var entregaKm = p.DistanciaEntregaKm
                                ?? (coleta is not null && destino is not null ? Math.Round(Geo.DistanciaKm(coleta, destino) * 1.3, 1) : 0);
                // Até a coleta: estimativa rápida (reta x 1,3); a rota real vem ao abrir a corrida.
                double? ateColeta = posicao is not null && coleta is not null ? Math.Round(Geo.DistanciaKm(posicao, coleta) * 1.3, 1) : null;
                var coletada = p.Status == StatusPedido.SaiuParaEntrega;
                var total = entregaKm + (coletada ? 0 : ateColeta ?? 0);
                return new CorridaDto(p.Id, p.Status, p.TaxaEntrega, p.Loja, Resumo(p.Coleta), coleta,
                    p.EnderecoEntrega?.Bairro ?? "",
                    minha ? Resumo(p.EnderecoEntrega!) : null,
                    minha ? destino : null,
                    minha ? p.Cliente.Split(' ')[0] : null,
                    ateColeta, Math.Round(entregaKm, 1), Math.Round(total, 1),
                    Math.Max(5, (int)Math.Ceiling(total / VelocidadeMotoKmH * 60)),
                    p.Quantidade, p.Oferta, minha ? p.Observacao : null, minha, coletada);
            })
            .Where(c => c.Minha || c.DistanciaAteColetaKm is null || c.DistanciaAteColetaKm <= eu.RaioCorridasKm)
            .OrderByDescending(c => c.Minha)
            .ThenBy(c => c.DistanciaAteColetaKm ?? double.MaxValue)
            .ToList();
        return corridas;
    }

    /// <summary>Rotas reais para o mapa da corrida: posição atual → loja (se ainda não coletou) e loja → cliente.</summary>
    public async Task<RotaCorridaDto> RotaAsync(int entregadorId, int pedidoId, Coordenada? posicao, CancellationToken ct)
    {
        var p = await db.Pedidos.AsNoTracking()
                    .Where(x => x.Id == pedidoId && x.TipoEntrega == TipoEntrega.Entrega
                                && (x.EntregadorId == entregadorId || (x.EntregadorId == null && StatusDisponivel.Contains(x.Status))))
                    .Select(x => new { x.Status, Coleta = x.Oferta.Estabelecimento.Endereco, x.EnderecoEntrega })
                    .FirstOrDefaultAsync(ct)
                ?? throw new NaoEncontradoException("Corrida não encontrada.");

        var coleta = Ponto(p.Coleta);
        var destino = p.EnderecoEntrega is null ? null : Ponto(p.EnderecoEntrega);
        if (coleta is null || destino is null)
            throw new RegraDeNegocioException("A loja ou o cliente estão sem localização no mapa.");

        var entrega = await mapas.CalcularRotaAsync(coleta, destino, ct);
        Rota? ateColeta = posicao is not null && p.Status != StatusPedido.SaiuParaEntrega
            ? await mapas.CalcularRotaAsync(posicao, coleta, ct)
            : null;

        return new RotaCorridaDto(ateColeta?.Pontos, entrega.Pontos, ateColeta?.DistanciaKm, entrega.DistanciaKm,
            entrega.MinutosEstimados + (ateColeta?.MinutosEstimados ?? 0));
    }

    /// <summary>Aceita a corrida. Só um entregador consegue: a troca é atômica no banco.</summary>
    public async Task AceitarAsync(int entregadorId, int pedidoId, CancellationToken ct)
    {
        if (!await db.Usuarios.AnyAsync(u => u.Id == entregadorId && u.Online, ct))
            throw new RegraDeNegocioException("Fique online para aceitar corridas.");
        if (await db.Pedidos.AnyAsync(p => p.Id == pedidoId && p.ClienteId == entregadorId, ct))
            throw new RegraDeNegocioException("Esse pedido é seu: outro entregador leva até você.");
        if (await db.Pedidos.AnyAsync(p => p.EntregadorId == entregadorId && StatusDisponivel.Contains(p.Status)
                                           || p.EntregadorId == entregadorId && p.Status == StatusPedido.SaiuParaEntrega, ct))
            throw new RegraDeNegocioException("Termine a corrida atual antes de aceitar outra.");

        var aceitas = await db.Pedidos
            .Where(p => p.Id == pedidoId && p.TipoEntrega == TipoEntrega.Entrega && p.EntregadorId == null
                        && StatusDisponivel.Contains(p.Status))
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.EntregadorId, entregadorId), ct);
        if (aceitas == 0)
            throw new RegraDeNegocioException("Essa corrida já foi aceita por outro entregador ou não está mais disponível.");

        await notificador.PedidoAlteradoAsync(pedidoId, ct);
    }

    /// <summary>Desiste antes de coletar: a corrida volta para os outros entregadores.</summary>
    public async Task DesistirAsync(int entregadorId, int pedidoId, CancellationToken ct)
    {
        var pedido = await MinhaAsync(entregadorId, pedidoId, ct);
        if (pedido.Status == StatusPedido.SaiuParaEntrega)
            throw new RegraDeNegocioException("O pedido já foi coletado; finalize a entrega.");
        pedido.EntregadorId = null;
        await db.SaveChangesAsync(ct);
        await notificador.PedidoAlteradoAsync(pedidoId, ct);
    }

    /// <summary>Pegou o pedido na loja e saiu para entregar.</summary>
    public async Task ColetarAsync(int entregadorId, int pedidoId, CancellationToken ct)
    {
        var pedido = await MinhaAsync(entregadorId, pedidoId, ct);
        if (pedido.Status != StatusPedido.ProntoParaRetirada)
            throw new RegraDeNegocioException("A loja ainda está preparando o pedido. Dá para coletar quando ela marcar como pronto.");
        pedido.AvancarStatus(StatusPedido.SaiuParaEntrega);
        await db.SaveChangesAsync(ct);
        await notificador.PedidoAlteradoAsync(pedido.Id, ct);
    }

    /// <summary>Posição enviada pelo app durante a corrida (a caminho da loja e da loja ao cliente, RN09).</summary>
    public async Task RegistrarPosicaoAsync(int entregadorId, int pedidoId, double latitude, double longitude, CancellationToken ct)
    {
        var pedido = await MinhaAsync(entregadorId, pedidoId, ct);
        pedido.Rastreios.Add(new RastreioEntrega { Latitude = latitude, Longitude = longitude, RegistradoEm = DateTimeOffset.UtcNow });
        await db.SaveChangesAsync(ct);
        await notificador.PosicaoEntregadorAsync(pedido.Id, latitude, longitude, ct);
    }

    /// <summary>Entrega concluída com o código de 4 dígitos que o cliente vê no app.</summary>
    public async Task ConcluirAsync(int entregadorId, int pedidoId, string codigo, CancellationToken ct)
    {
        var pedido = await MinhaAsync(entregadorId, pedidoId, ct);
        if (pedido.Status != StatusPedido.SaiuParaEntrega)
            throw new RegraDeNegocioException("Colete o pedido na loja antes de finalizar.");
        if (codigo.Trim() != pedido.CodigoRetirada)
            throw new RegraDeNegocioException("Código incorreto. Peça ao cliente o código que aparece no pedido dele.");

        pedido.AvancarStatus(StatusPedido.Entregue);
        await db.SaveChangesAsync(ct);
        await notificador.PedidoAlteradoAsync(pedido.Id, ct);
    }

    /// <summary>Liga ou desliga o recebimento de corridas. A corrida em andamento continua com ele.</summary>
    public async Task<bool> DefinirOnlineAsync(int entregadorId, bool online, CancellationToken ct)
    {
        await db.Usuarios.Where(u => u.Id == entregadorId).ExecuteUpdateAsync(s => s.SetProperty(u => u.Online, online), ct);
        return online;
    }

    /// <summary>Ganhos reais do entregador (horário de Brasília): taxas das corridas que ele entregou.</summary>
    public async Task<GanhosDto> GanhosAsync(int entregadorId, CancellationToken ct)
    {
        var fuso = TimeZoneInfo.FindSystemTimeZoneById("America/Sao_Paulo");
        var agoraLocal = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, fuso);
        var inicioHoje = new DateTimeOffset(agoraLocal.Date, agoraLocal.Offset);
        var inicioSemana = inicioHoje.AddDays(-(((int)agoraLocal.DayOfWeek + 6) % 7)); // segunda-feira
        var inicioMes = new DateTimeOffset(new DateTime(agoraLocal.Year, agoraLocal.Month, 1), agoraLocal.Offset);

        var entregues = (await db.Pedidos.AsNoTracking()
                .Where(p => p.EntregadorId == entregadorId && p.Status == StatusPedido.Entregue)
                .Select(p => new
                {
                    p.Id, p.TaxaEntrega, Km = p.DistanciaEntregaKm ?? 0, Loja = p.Oferta.Estabelecimento.Nome,
                    Bairro = p.EnderecoEntrega != null ? p.EnderecoEntrega.Bairro : "", p.NotaEntregador, p.ComentarioEntregador,
                    p.CriadoEm,
                    Entregue = p.Historico.Where(h => h.StatusNovo == StatusPedido.Entregue).Max(h => (DateTimeOffset?)h.AlteradoEm)
                })
                .ToListAsync(ct))
            .Select(e => new
            {
                e.Id, e.TaxaEntrega, e.Km, e.Loja, e.Bairro, e.NotaEntregador, e.ComentarioEntregador,
                Em = TimeZoneInfo.ConvertTime(e.Entregue ?? e.CriadoEm, fuso)
            })
            .OrderByDescending(e => e.Em)
            .ToList();

        var hoje = entregues.Where(e => e.Em >= inicioHoje).ToList();
        var semana = entregues.Where(e => e.Em >= inicioSemana).ToList();
        var mes = entregues.Where(e => e.Em >= inicioMes).ToList();

        var dias = Enumerable.Range(0, 7)
            .Select(i => DateOnly.FromDateTime(agoraLocal.Date.AddDays(i - 6)))
            .Select(d =>
            {
                var doDia = entregues.Where(e => DateOnly.FromDateTime(e.Em.Date) == d).ToList();
                return new GanhoDiaDto(d, doDia.Sum(e => e.TaxaEntrega), doDia.Count);
            })
            .ToList();

        return new GanhosDto(hoje.Count, hoje.Sum(e => e.TaxaEntrega), Km(hoje.Sum(e => e.Km)),
            semana.Count, semana.Sum(e => e.TaxaEntrega), Km(semana.Sum(e => e.Km)),
            mes.Count, mes.Sum(e => e.TaxaEntrega), Km(mes.Sum(e => e.Km)),
            entregues.Count, entregues.Sum(e => e.TaxaEntrega), dias,
            entregues.Take(30)
                .Select(e => new CorridaFeitaDto(e.Id, e.Em, e.Loja, e.Bairro, e.TaxaEntrega, Km(e.Km), e.NotaEntregador, e.ComentarioEntregador))
                .ToList());

        static double Km(double km) => Math.Round(km, 1);
    }

    public async Task<PerfilEntregadorDto> PerfilAsync(int entregadorId, CancellationToken ct)
    {
        var u = await db.Usuarios.AsNoTracking().FirstOrDefaultAsync(x => x.Id == entregadorId, ct)
                ?? throw new NaoEncontradoException("Entregador não encontrado.");

        var corridas = await db.Pedidos.CountAsync(p => p.EntregadorId == entregadorId && p.Status == StatusPedido.Entregue, ct);
        var notas = await db.Pedidos.AsNoTracking()
            .Where(p => p.EntregadorId == entregadorId && p.NotaEntregador != null)
            .OrderByDescending(p => p.EntregadorAvaliadoEm)
            .Select(p => new { Nota = p.NotaEntregador!.Value, p.ComentarioEntregador, Cliente = p.Cliente.Nome, Em = p.EntregadorAvaliadoEm!.Value })
            .ToListAsync(ct);

        return new PerfilEntregadorDto(u.Nome, u.Email, u.Telefone, u.Placa, u.ModeloMoto, u.Online, u.RaioCorridasKm,
            notas.Count == 0 ? null : Math.Round(notas.Average(n => n.Nota), 2), notas.Count,
            Enumerable.Range(1, 5).Reverse().Select(e => notas.Count(n => n.Nota == e)).ToList(),
            corridas, u.CriadoEm,
            notas.Take(10).Select(n => new AvaliacaoEntregadorDto(n.Nota, n.ComentarioEntregador, n.Cliente.Split(' ')[0], n.Em)).ToList());
    }

    public async Task<PerfilEntregadorDto> AtualizarPerfilAsync(int entregadorId, AtualizarPerfilEntregadorRequest request, CancellationToken ct)
    {
        var u = await db.Usuarios.FirstOrDefaultAsync(x => x.Id == entregadorId, ct)
                ?? throw new NaoEncontradoException("Entregador não encontrado.");
        u.Nome = request.Nome.Trim();
        u.Telefone = request.Telefone.Trim();
        u.Placa = request.Placa.Replace("-", "").Trim().ToUpperInvariant();
        u.ModeloMoto = string.IsNullOrWhiteSpace(request.ModeloMoto) ? null : request.ModeloMoto.Trim();
        u.RaioCorridasKm = request.RaioCorridasKm;
        await db.SaveChangesAsync(ct);
        return await PerfilAsync(entregadorId, ct);
    }

    private async Task<Pedido> MinhaAsync(int entregadorId, int pedidoId, CancellationToken ct) =>
        await db.Pedidos.FirstOrDefaultAsync(p => p.Id == pedidoId && p.EntregadorId == entregadorId
                                                  && p.TipoEntrega == TipoEntrega.Entrega, ct)
        ?? throw new NaoEncontradoException("Essa corrida não está com você.");

    private static Coordenada? Ponto(Endereco e) =>
        e.Latitude is { } la && e.Longitude is { } lo ? new Coordenada(la, lo) : null;

    private static string Resumo(Endereco e) =>
        $"{e.Logradouro}, {e.Numero}{(string.IsNullOrWhiteSpace(e.Complemento) ? "" : " - " + e.Complemento)} · {e.Bairro}";
}
