using Microsoft.EntityFrameworkCore;
using Xepa.Domain.Entities;

namespace Xepa.Application.Ofertas;

/// <summary>Consultas de ofertas do app: listagem com busca e distância, e detalhe.</summary>
public class OfertaConsultaService(IXepaDb db)
{
    private const double RaioTerraKm = 6371;
    private const double GrausParaRadianos = Math.PI / 180;

    /// <summary>Ofertas disponíveis agora (RN01), com busca, categoria e ordenação por distância.</summary>
    public async Task<PaginaDto<OfertaDto>> ListarAsync(FiltroOfertas filtro, CancellationToken ct)
    {
        var agora = DateTimeOffset.UtcNow;
        var ofertas = db.Ofertas.Where(o => o.Ativa
                                            && o.Estabelecimento.Ativo
                                            && o.Estabelecimento.StatusCadastro == StatusCadastro.Aprovado
                                            && o.QuantidadeDisponivel > 0
                                            && o.RetiradaFim > agora);

        if (!string.IsNullOrWhiteSpace(filtro.Busca))
        {
            var busca = filtro.Busca.Trim();
            ofertas = ofertas.Where(o => o.Titulo.Contains(busca) || o.Estabelecimento.Nome.Contains(busca));
        }

        if (filtro.Categoria is { } categoria)
            ofertas = ofertas.Where(o => o.Estabelecimento.Categoria == categoria);

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

        return new PaginaDto<OfertaDto>(itens, filtro.Pagina, filtro.TamanhoPagina, total);
    }

    /// <summary>Detalhe de uma oferta. Latitude e longitude são opcionais, só para trazer a distância.</summary>
    public Task<OfertaDto?> ObterAsync(int id, double? latitude, double? longitude, CancellationToken ct) =>
        Projetar(db.Ofertas.Where(o => o.Id == id && o.Ativa), latitude, longitude).FirstOrDefaultAsync(ct);

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
                Longitude = o.Estabelecimento.Endereco.Longitude
            }
        });
    }
}
