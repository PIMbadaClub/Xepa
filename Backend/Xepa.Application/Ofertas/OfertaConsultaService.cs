using Microsoft.EntityFrameworkCore;
using Xepa.Domain.Entities;

namespace Xepa.Application.Ofertas;

/// <summary>Consultas de ofertas do app: listagem com busca e distância, e detalhe.</summary>
public class OfertaConsultaService(IXepaDb db)
{
    private const double RaioTerraKm = 6371;
    private const double GrausParaRadianos = Math.PI / 180;

    // O banco da Azure foi criado com a collation padrão, que diferencia acentos: "cafe" não achava "café".
    private const string SemAcento = "Latin1_General_100_CI_AI";

    /// <summary>Ofertas disponíveis agora (RN01), com busca, categoria e ordenação por distância.</summary>
    public async Task<PaginaDto<OfertaDto>> ListarAsync(FiltroOfertas filtro, CancellationToken ct)
    {
        var agora = DateTimeOffset.UtcNow;
        var ofertas = db.Ofertas.Where(o => o.Ativa
                                            && o.Estabelecimento.Ativo
                                            && o.Estabelecimento.StatusCadastro == StatusCadastro.Aprovado
                                            && !o.Estabelecimento.Pausada
                                            && o.QuantidadeDisponivel > 0
                                            && o.RetiradaFim > agora);

        if (!string.IsNullOrWhiteSpace(filtro.Busca))
        {
            var busca = filtro.Busca.Trim();
            ofertas = ofertas.Where(o => EF.Functions.Collate(o.Titulo, SemAcento).Contains(busca)
                                         || EF.Functions.Collate(o.Estabelecimento.Nome, SemAcento).Contains(busca));
        }

        if (filtro.Categoria is { } categoria)
            ofertas = ofertas.Where(o => o.Estabelecimento.Categoria == categoria);

        // Ignora maiúsculas e acentos: "limeira" encontra "Limeira".
        if (!string.IsNullOrWhiteSpace(filtro.Cidade))
        {
            var cidade = filtro.Cidade.Trim();
            ofertas = ofertas.Where(o => EF.Functions.Collate(o.Estabelecimento.Endereco.Cidade, SemAcento) == cidade);
        }

        if (filtro.EstabelecimentoId is { } estabelecimentoId)
            ofertas = ofertas.Where(o => o.EstabelecimentoId == estabelecimentoId);

        var consulta = Projetar(ofertas, filtro.Latitude, filtro.Longitude);

        if (filtro.RaioKm is { } raioKm)
            consulta = consulta.Where(o => o.DistanciaKm <= raioKm);

        consulta = filtro.Latitude.HasValue
            ? consulta.OrderBy(o => o.DistanciaKm == null).ThenBy(o => o.DistanciaKm).ThenBy(o => o.Id)
            : consulta.OrderBy(o => o.RetiradaFim).ThenBy(o => o.Id);

        var total = await consulta.CountAsync(ct);
        var itens = await consulta
            .Skip((filtro.Pagina - 1) * filtro.TamanhoPagina)
            .Take(filtro.TamanhoPagina)
            .ToListAsync(ct);

        await PreencherFuncionamentoAsync(itens, comHorarios: false, ct);
        return new PaginaDto<OfertaDto>(itens, filtro.Pagina, filtro.TamanhoPagina, total);
    }

    /// <summary>Calcula "aberta agora" no horário de Brasília para as lojas das ofertas (e o horário da semana no detalhe).</summary>
    private async Task PreencherFuncionamentoAsync(IReadOnlyCollection<OfertaDto> ofertas, bool comHorarios, CancellationToken ct)
    {
        var ids = ofertas.Select(o => o.Estabelecimento.Id).Distinct().ToList();
        if (ids.Count == 0)
            return;
        var horarios = (await db.Estabelecimentos.AsNoTracking().Where(e => ids.Contains(e.Id))
                .Select(e => new { e.Id, e.Horarios }).ToListAsync(ct))
            .ToDictionary(e => e.Id, e => e.Horarios);
        var agora = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, OfertaGestaoService.FusoBrasilia).DateTime;

        foreach (var oferta in ofertas)
        {
            var daLoja = horarios.GetValueOrDefault(oferta.Estabelecimento.Id) ?? [];
            var situacao = Domain.Entities.Funcionamento.Situacao(daLoja, agora);
            oferta.Estabelecimento.Funcionamento = situacao.TemHorario ? situacao.Texto : null;
            oferta.Estabelecimento.Aberta = situacao.TemHorario ? situacao.Aberta : null;
            if (comHorarios && daLoja.Count > 0)
                oferta.Estabelecimento.Horarios = Enum.GetValues<DayOfWeek>()
                    .Select(d => daLoja.FirstOrDefault(h => h.DiaSemana == d) is { } h
                        ? new HorarioDiaDto(Domain.Entities.Funcionamento.NomeDia(d), h.Abre.ToString("HH:mm"), h.Fecha.ToString("HH:mm"))
                        : new HorarioDiaDto(Domain.Entities.Funcionamento.NomeDia(d), null, null))
                    .ToList();
        }
    }

    /// <summary>Detalhe de uma oferta. Latitude e longitude são opcionais, só para trazer a distância.</summary>
    public async Task<OfertaDto?> ObterAsync(int id, double? latitude, double? longitude, CancellationToken ct)
    {
        var oferta = await Projetar(db.Ofertas.Where(o => o.Id == id && o.Ativa), latitude, longitude).FirstOrDefaultAsync(ct);
        if (oferta is not null)
            await PreencherFuncionamentoAsync([oferta], comHorarios: true, ct);
        return oferta;
    }

    /// <summary>
    /// Monta o DTO direto no SELECT, com a distância calculada no banco pela fórmula de Haversine.
    /// </summary>
    private static IQueryable<OfertaDto> Projetar(IQueryable<Oferta> ofertas, double? latitude, double? longitude)
    {
        var temLocal = latitude.HasValue && longitude.HasValue;
        var lat = (latitude ?? 0) * GrausParaRadianos;
        var lng = (longitude ?? 0) * GrausParaRadianos;
        var cosLat = Math.Cos(lat);

        return ofertas.Select(o => new OfertaDto
        {
            Id = o.Id,
            Tipo = o.Tipo,
            Titulo = o.Titulo,
            Descricao = o.Descricao,
            FotoUrl = o.FotoUrl,
            PrecoOriginal = o.PrecoOriginal,
            Preco = o.Preco,
            Restantes = o.QuantidadeDisponivel,
            KgSalvos = o.PesoEstimadoKg,
            RetiradaInicio = o.RetiradaInicio,
            RetiradaFim = o.RetiradaFim,
            DistanciaKm = !temLocal
                          || o.Estabelecimento.Endereco.Latitude == null
                          || o.Estabelecimento.Endereco.Longitude == null
                ? null
                : 2 * RaioTerraKm * Math.Asin(Math.Sqrt(
                    Math.Pow(Math.Sin((o.Estabelecimento.Endereco.Latitude.Value * GrausParaRadianos - lat) / 2), 2)
                    + cosLat * Math.Cos(o.Estabelecimento.Endereco.Latitude.Value * GrausParaRadianos)
                    * Math.Pow(Math.Sin((o.Estabelecimento.Endereco.Longitude.Value * GrausParaRadianos - lng) / 2), 2))),
            Estabelecimento = new EstabelecimentoResumoDto
            {
                Id = o.Estabelecimento.Id,
                Nome = o.Estabelecimento.Nome,
                Categoria = o.Estabelecimento.Categoria,
                LogoUrl = o.Estabelecimento.LogoUrl,
                Bairro = o.Estabelecimento.Endereco.Bairro,
                Latitude = o.Estabelecimento.Endereco.Latitude,
                Longitude = o.Estabelecimento.Endereco.Longitude,
                Nota = o.Estabelecimento.Ofertas.SelectMany(x => x.Pedidos).Where(p => p.NotaLoja != null)
                    .Average(p => (double?)p.NotaLoja),
                Avaliacoes = o.Estabelecimento.Ofertas.SelectMany(x => x.Pedidos).Count(p => p.NotaLoja != null)
            }
        });
    }
}
