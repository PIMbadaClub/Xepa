using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Xepa.Application.Indicadores;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Ofertas;

public record OfertaPainelDto(int Id, string Titulo, string? FotoUrl, decimal Preco, int Restantes, int Vendidas,
    DateTimeOffset Inicio, DateTimeOffset Fim, string? Alerta, bool Urgente);

/// <summary>Algo que falta no perfil da loja, com a âncora da seção em Configurações.</summary>
public record PendenciaPerfilDto(string Texto, string Secao);

/// <summary>Tela inicial do portal da loja: o que fazer agora, como vai o dia e o que falta no perfil.</summary>
public record PainelLojaDto(string Nome, string? LogoUrl, StatusCadastro Status, bool Ativa, bool Pausada,
    SituacaoFuncionamento Funcionamento, int AguardandoAceite, int EmPreparo, int Prontos, int EmRota, int EntreguesHoje,
    int CanceladosHoje, decimal VendasHoje, decimal VendasOntem, decimal KgHoje, decimal RepasseAReceber,
    IReadOnlyList<OfertaPainelDto> OfertasNoAr, int OfertasParaRepetir, IReadOnlyList<VendaDiaDto> UltimosDias,
    ReputacaoLojaDto Reputacao, IReadOnlyList<PendenciaPerfilDto> Pendencias, int PerfilCompleto);

public class HorarioForm
{
    public DayOfWeek Dia { get; set; }
    public bool Aberto { get; set; }

    [RegularExpression(@"^([01]\d|2[0-3]):[0-5]\d$", ErrorMessage = "Hora inválida.")]
    public string? Abre { get; set; }

    [RegularExpression(@"^([01]\d|2[0-3]):[0-5]\d$", ErrorMessage = "Hora inválida.")]
    public string? Fecha { get; set; }
}

public class AlterarSenhaLojaForm
{
    [Required(ErrorMessage = "Informe a senha atual."), DataType(DataType.Password), Display(Name = "Senha atual")]
    public string SenhaAtual { get; set; } = "";

    [Required(ErrorMessage = "Informe a nova senha."), MinLength(8, ErrorMessage = "Mínimo de 8 caracteres."),
     DataType(DataType.Password), Display(Name = "Nova senha")]
    public string NovaSenha { get; set; } = "";

    [Compare(nameof(NovaSenha), ErrorMessage = "As senhas não conferem."), DataType(DataType.Password), Display(Name = "Confirmar nova senha")]
    public string Confirmacao { get; set; } = "";
}

/// <summary>Painel e configurações do portal do estabelecimento.</summary>
public class LojaPainelService(IXepaDb db, IndicadoresService indicadores, IHasherSenha hasher, IArmazenamento armazenamento)
{
    /// <summary>Ordem dos dias na tela: segunda a domingo.</summary>
    public static readonly DayOfWeek[] Semana =
        [DayOfWeek.Monday, DayOfWeek.Tuesday, DayOfWeek.Wednesday, DayOfWeek.Thursday, DayOfWeek.Friday, DayOfWeek.Saturday, DayOfWeek.Sunday];

    public async Task<PainelLojaDto> PainelAsync(int estabelecimentoId, CancellationToken ct)
    {
        var fuso = OfertaGestaoService.FusoBrasilia;
        var agora = DateTimeOffset.UtcNow;
        var agoraLocal = TimeZoneInfo.ConvertTime(agora, fuso);
        var inicioHoje = new DateTimeOffset(agoraLocal.Date, agoraLocal.Offset);
        var inicioOntem = inicioHoje.AddDays(-1);

        var loja = await db.Estabelecimentos.AsNoTracking().Include(e => e.Horarios)
                       .FirstOrDefaultAsync(e => e.Id == estabelecimentoId, ct)
                   ?? throw new NaoEncontradoException("Loja não encontrada.");

        var daLoja = db.Pedidos.AsNoTracking().Where(p => p.Oferta.EstabelecimentoId == estabelecimentoId);
        var porStatus = await daLoja
            .Where(p => p.Status != StatusPedido.AguardandoPagamento && (p.CriadoEm >= inicioOntem
                        || p.Status == StatusPedido.Pendente || p.Status == StatusPedido.Confirmado || p.Status == StatusPedido.EmPreparo
                        || p.Status == StatusPedido.ProntoParaRetirada || p.Status == StatusPedido.SaiuParaEntrega))
            .Select(p => new { p.Status, p.CriadoEm, Vendas = p.PrecoUnitario * p.Quantidade, Kg = (p.Oferta.PesoEstimadoKg ?? 0) * p.Quantidade })
            .ToListAsync(ct);

        var entreguesHoje = porStatus.Where(p => p.Status == StatusPedido.Entregue && p.CriadoEm >= inicioHoje).ToList();
        var vendasOntem = porStatus.Where(p => p.Status == StatusPedido.Entregue && p.CriadoEm >= inicioOntem && p.CriadoEm < inicioHoje)
            .Sum(p => p.Vendas);

        var ofertas = await db.Ofertas.AsNoTracking()
            .Where(o => o.EstabelecimentoId == estabelecimentoId && o.Ativa && o.RetiradaFim > agora.AddHours(-12))
            .OrderBy(o => o.RetiradaFim)
            .Select(o => new
            {
                o.Id, o.Titulo, o.FotoUrl, o.Preco, o.QuantidadeDisponivel, o.RetiradaInicio, o.RetiradaFim,
                Vendidas = o.Pedidos.Where(p => p.Status != StatusPedido.Cancelado && p.Status != StatusPedido.AguardandoPagamento)
                    .Sum(p => (int?)p.Quantidade) ?? 0
            })
            .ToListAsync(ct);

        var noAr = ofertas.Select(o =>
        {
            var (alerta, urgente) = o.RetiradaFim <= agora ? ("Janela de retirada encerrada", true)
                : o.QuantidadeDisponivel == 0 ? ("Esgotada", false)
                : o.RetiradaInicio > agora ? ($"Retirada começa às {TimeZoneInfo.ConvertTime(o.RetiradaInicio, fuso):HH:mm}", false)
                : o.RetiradaFim - agora <= TimeSpan.FromHours(1) ? ($"Termina em {(int)Math.Ceiling((o.RetiradaFim - agora).TotalMinutes)} min", true)
                : ((string?)null, false);
            return new OfertaPainelDto(o.Id, o.Titulo, o.FotoUrl, o.Preco, o.QuantidadeDisponivel, o.Vendidas, o.RetiradaInicio,
                o.RetiradaFim, alerta, urgente);
        }).ToList();

        var indicadoresSemana = await indicadores.DaLojaAsync(estabelecimentoId, 7, ct);
        var reputacao = await indicadores.ReputacaoLojaAsync(estabelecimentoId, ct);

        var pendencias = new List<PendenciaPerfilDto>();
        if (loja.Horarios.Count == 0) pendencias.Add(new("Cadastre o horário de funcionamento", "horarios"));
        if (loja.LogoUrl is null) pendencias.Add(new("Envie o logotipo da loja", "dados"));
        if (string.IsNullOrWhiteSpace(loja.Descricao)) pendencias.Add(new("Escreva uma descrição curta da loja", "dados"));
        if (string.IsNullOrWhiteSpace(loja.Telefone)) pendencias.Add(new("Informe um telefone de contato", "dados"));
        if (loja.Endereco.Latitude is null) pendencias.Add(new("Confira o endereço: a loja não aparece no mapa", "endereco"));
        const int itensPerfil = 5;

        return new PainelLojaDto(loja.Nome, loja.LogoUrl, loja.StatusCadastro, loja.Ativo, loja.Pausada,
            Funcionamento.Situacao(loja.Horarios, agoraLocal.DateTime),
            porStatus.Count(p => p.Status == StatusPedido.Pendente),
            porStatus.Count(p => p.Status is StatusPedido.Confirmado or StatusPedido.EmPreparo),
            porStatus.Count(p => p.Status == StatusPedido.ProntoParaRetirada),
            porStatus.Count(p => p.Status == StatusPedido.SaiuParaEntrega),
            entreguesHoje.Count,
            porStatus.Count(p => p.Status == StatusPedido.Cancelado && p.CriadoEm >= inicioHoje),
            entreguesHoje.Sum(p => p.Vendas), vendasOntem, entreguesHoje.Sum(p => p.Kg), indicadoresSemana.RepasseAReceber,
            noAr, await ContarParaRepetirAsync(estabelecimentoId, ct), indicadoresSemana.PorDia, reputacao, pendencias,
            (itensPerfil - pendencias.Count) * 100 / itensPerfil);
    }

    // ---------- Repetir ofertas ----------

    /// <summary>Ofertas cuja janela de retirada terminou nas últimas 48 h e que ainda não têm cópia no ar.</summary>
    private IQueryable<Oferta> ParaRepetir(int estabelecimentoId)
    {
        var agora = DateTimeOffset.UtcNow;
        var desde = agora.AddHours(-48);
        return db.Ofertas.Where(o => o.EstabelecimentoId == estabelecimentoId && o.RetiradaFim <= agora && o.RetiradaFim > desde
                                     && !db.Ofertas.Any(n => n.EstabelecimentoId == estabelecimentoId && n.Ativa && n.RetiradaFim > agora
                                                             && n.Titulo == o.Titulo));
    }

    public Task<int> ContarParaRepetirAsync(int estabelecimentoId, CancellationToken ct) =>
        ParaRepetir(estabelecimentoId).Select(o => o.Titulo).Distinct().CountAsync(ct);

    /// <summary>
    /// Publica de novo as ofertas que acabaram ontem: mesmo título, preço e foto, a quantidade do lote original
    /// e a mesma janela de horário (hoje, ou amanhã se o horário de hoje já passou).
    /// </summary>
    public async Task<int> RepetirOfertasAsync(int estabelecimentoId, CancellationToken ct)
    {
        var fuso = OfertaGestaoService.FusoBrasilia;
        var agora = DateTimeOffset.UtcNow;
        var originais = await ParaRepetir(estabelecimentoId)
            .Select(o => new
            {
                Oferta = o,
                Lote = o.QuantidadeDisponivel + (o.Pedidos.Where(p => p.Status != StatusPedido.Cancelado && p.Status != StatusPedido.AguardandoPagamento)
                    .Sum(p => (int?)p.Quantidade) ?? 0)
            })
            .ToListAsync(ct);
        // Se a mesma oferta aparece duas vezes (ontem e anteontem), repete só a mais recente.
        var escolhidas = originais.GroupBy(o => o.Oferta.Titulo).Select(g => g.OrderByDescending(o => o.Oferta.RetiradaFim).First()).ToList();
        if (escolhidas.Count == 0)
            throw new RegraDeNegocioException("Não há ofertas de ontem para repetir.");

        var hoje = TimeZoneInfo.ConvertTime(agora, fuso).Date;
        foreach (var (o, lote) in escolhidas.Select(e => (e.Oferta, e.Lote)))
        {
            var inicioLocal = TimeZoneInfo.ConvertTime(o.RetiradaInicio, fuso);
            var fimLocal = TimeZoneInfo.ConvertTime(o.RetiradaFim, fuso);
            var duracao = fimLocal - inicioLocal;
            var novoInicio = hoje + inicioLocal.TimeOfDay;
            if (DeBrasilia(novoInicio + duracao) <= agora)
                novoInicio = novoInicio.AddDays(1);

            var copia = new Oferta
            {
                EstabelecimentoId = estabelecimentoId, Tipo = o.Tipo, Titulo = o.Titulo, Descricao = o.Descricao, FotoUrl = o.FotoUrl,
                PrecoOriginal = o.PrecoOriginal, Preco = o.Preco, QuantidadeDisponivel = Math.Max(1, lote), PesoEstimadoKg = o.PesoEstimadoKg,
                RetiradaInicio = DeBrasilia(novoInicio), RetiradaFim = DeBrasilia(novoInicio + duracao), Ativa = true
            };
            copia.Validar();
            db.Ofertas.Add(copia);
        }
        await db.SaveChangesAsync(ct);
        return escolhidas.Count;
    }

    // ---------- Configurações ----------

    public async Task<IReadOnlyList<HorarioForm>> HorariosAsync(int estabelecimentoId, CancellationToken ct)
    {
        var horarios = await db.Estabelecimentos.AsNoTracking().Where(e => e.Id == estabelecimentoId)
            .SelectMany(e => e.Horarios).ToListAsync(ct);
        return Semana.Select(d => horarios.FirstOrDefault(h => h.DiaSemana == d) is { } h
                ? new HorarioForm { Dia = d, Aberto = true, Abre = h.Abre.ToString("HH:mm"), Fecha = h.Fecha.ToString("HH:mm") }
                : new HorarioForm { Dia = d, Aberto = false, Abre = "08:00", Fecha = "18:00" })
            .ToList();
    }

    public async Task SalvarHorariosAsync(int estabelecimentoId, IReadOnlyList<HorarioForm> dias, CancellationToken ct)
    {
        var loja = await db.Estabelecimentos.Include(e => e.Horarios).FirstOrDefaultAsync(e => e.Id == estabelecimentoId, ct)
                   ?? throw new NaoEncontradoException("Loja não encontrada.");
        var abertos = new List<(DayOfWeek, TimeOnly, TimeOnly)>();
        foreach (var d in dias.Where(d => d.Aberto))
        {
            if (!TimeOnly.TryParse(d.Abre, out var abre) || !TimeOnly.TryParse(d.Fecha, out var fecha))
                throw new RegraDeNegocioException($"Informe a hora de abrir e de fechar na {Funcionamento.NomeDia(d.Dia)}.");
            abertos.Add((d.Dia, abre, fecha));
        }
        loja.DefinirHorarios(abertos);
        await db.SaveChangesAsync(ct);
    }

    public async Task DefinirPausaAsync(int estabelecimentoId, bool pausada, CancellationToken ct)
    {
        var alterados = await db.Estabelecimentos.Where(e => e.Id == estabelecimentoId)
            .ExecuteUpdateAsync(s => s.SetProperty(e => e.Pausada, pausada), ct);
        if (alterados == 0)
            throw new NaoEncontradoException("Loja não encontrada.");
    }

    public async Task AtualizarLogoAsync(int estabelecimentoId, Foto logo, CancellationToken ct)
    {
        var loja = await db.Estabelecimentos.FirstOrDefaultAsync(e => e.Id == estabelecimentoId, ct)
                   ?? throw new NaoEncontradoException("Loja não encontrada.");
        loja.LogoUrl = await Fotos.SalvarAsync(armazenamento, logo, ct);
        await db.SaveChangesAsync(ct);
    }

    /// <summary>Troca a senha do responsável conferindo a atual; as sessões do app abertas com ela são encerradas.</summary>
    public async Task AlterarSenhaAsync(int usuarioId, AlterarSenhaLojaForm form, CancellationToken ct)
    {
        var usuario = await db.Usuarios.FirstOrDefaultAsync(u => u.Id == usuarioId, ct)
                      ?? throw new NaoEncontradoException("Usuário não encontrado.");
        if (!hasher.Conferir(usuario, form.SenhaAtual))
            throw new RegraDeNegocioException("A senha atual não confere.");
        if (form.SenhaAtual == form.NovaSenha)
            throw new RegraDeNegocioException("A nova senha precisa ser diferente da atual.");
        usuario.SenhaHash = hasher.Gerar(usuario, form.NovaSenha);
        var agora = DateTimeOffset.UtcNow;
        await foreach (var token in db.TokensRenovacao.Where(t => t.UsuarioId == usuarioId && t.RevogadoEm == null).AsAsyncEnumerable().WithCancellation(ct))
            token.RevogadoEm = agora;
        await db.SaveChangesAsync(ct);
    }

    private static DateTimeOffset DeBrasilia(DateTime horaLocal)
    {
        var local = DateTime.SpecifyKind(horaLocal, DateTimeKind.Unspecified);
        return new DateTimeOffset(local, OfertaGestaoService.FusoBrasilia.GetUtcOffset(local)).ToUniversalTime();
    }
}
