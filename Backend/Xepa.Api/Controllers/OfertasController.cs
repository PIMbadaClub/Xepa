using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xepa.Api.Data;
using Xepa.Api.Dtos;
using Xepa.Api.Entities;

namespace Xepa.Api.Controllers;

[ApiController]
[Route("api/ofertas")]
public class OfertasController(XepaDbContext db) : ControllerBase
{
    private const double RaioTerraKm = 6371;
    private const double GrausParaRadianos = Math.PI / 180;

    /// <summary>Ofertas disponíveis agora, com busca, categoria e ordenação por distância (RF09, RF11, RF12).</summary>
    [HttpGet]
    public async Task<ActionResult<PaginaDto<OfertaDto>>> Listar([FromQuery] FiltroOfertas filtro, CancellationToken ct)
    {
        var agora = DateTimeOffset.UtcNow;
        var ofertas = db.Ofertas.Where(o => o.Ativa
                                            && o.Estabelecimento.Ativo
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

    /// <summary>Detalhe de uma oferta (RF10). Latitude e longitude são opcionais, só para trazer a distância.</summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<OfertaDto>> Obter(int id, [FromQuery] double? latitude, [FromQuery] double? longitude,
        CancellationToken ct)
    {
        var oferta = await Projetar(db.Ofertas.Where(o => o.Id == id && o.Ativa), latitude, longitude)
            .FirstOrDefaultAsync(ct);

        return oferta is null ? NotFound() : oferta;
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
