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

public record GanhosDto(int CorridasHoje, decimal GanhosHoje, double KmHoje, int CorridasSemana, decimal GanhosSemana);

/// <summary>Traçados para o mapa do entregador: até a loja (antes de coletar) e da loja ao cliente.</summary>
public record RotaCorridaDto(IReadOnlyList<Coordenada>? AteColeta, IReadOnlyList<Coordenada>? Entrega, double? DistanciaAteColetaKm,
    double DistanciaEntregaKm, int MinutosEstimados);

/// <summary>
/// Entregadores parceiros da XEPA: veem as corridas perto deles, aceitam, coletam na loja e entregam com o código
/// do cliente. A taxa de entrega paga pelo cliente vai inteira para o entregador.
/// </summary>
public class EntregaService(IXepaDb db, IServicoMapas mapas, INotificadorPedidos notificador)
{
    /// <summary>Corridas disponíveis num raio de até 15 km do entregador (pela loja de coleta).</summary>
    public const double RaioOfertaKm = 15;

    /// <summary>Velocidade média de moto na cidade, para estimar o tempo quando não há rota calculada.</summary>
    private const double VelocidadeMotoKmH = 25;

    /// <summary>A corrida pode ser aceita desde que a loja aceita o pedido até ela marcar pronto.</summary>
    private static readonly StatusPedido[] StatusDisponivel = [StatusPedido.Confirmado, StatusPedido.EmPreparo, StatusPedido.ProntoParaRetirada];

    public async Task<IReadOnlyList<CorridaDto>> ListarAsync(int entregadorId, Coordenada? posicao, CancellationToken ct)
    {
        var pedidos = await db.Pedidos.AsNoTracking()
            .Where(p => p.TipoEntrega == TipoEntrega.Entrega
                        && ((p.EntregadorId == null && StatusDisponivel.Contains(p.Status))
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
            .Where(c => c.Minha || c.DistanciaAteColetaKm is null || c.DistanciaAteColetaKm <= RaioOfertaKm)
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

    /// <summary>Ganhos do entregador (horário de Brasília): taxas das corridas entregues.</summary>
    public async Task<GanhosDto> GanhosAsync(int entregadorId, CancellationToken ct)
    {
        var fuso = TimeZoneInfo.FindSystemTimeZoneById("America/Sao_Paulo");
        var agoraLocal = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, fuso);
        var inicioHoje = new DateTimeOffset(agoraLocal.Date, agoraLocal.Offset);
        var inicioSemana = inicioHoje.AddDays(-(((int)agoraLocal.DayOfWeek + 6) % 7)); // segunda-feira

        var entregues = await db.Pedidos.AsNoTracking()
            .Where(p => p.EntregadorId == entregadorId && p.Status == StatusPedido.Entregue
                        && p.Historico.Any(h => h.StatusNovo == StatusPedido.Entregue && h.AlteradoEm >= inicioSemana))
            .Select(p => new
            {
                p.TaxaEntrega,
                Km = p.DistanciaEntregaKm ?? 0,
                Em = p.Historico.Where(h => h.StatusNovo == StatusPedido.Entregue).Max(h => h.AlteradoEm)
            })
            .ToListAsync(ct);

        var hoje = entregues.Where(e => e.Em >= inicioHoje).ToList();
        return new GanhosDto(hoje.Count, hoje.Sum(e => e.TaxaEntrega), Math.Round(hoje.Sum(e => e.Km), 1),
            entregues.Count, entregues.Sum(e => e.TaxaEntrega));
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
