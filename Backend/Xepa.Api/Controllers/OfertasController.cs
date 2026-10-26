using Microsoft.AspNetCore.Mvc;
using Xepa.Application;
using Xepa.Application.Ofertas;

namespace Xepa.Api.Controllers;

[ApiController]
[Route("api/ofertas")]
public class OfertasController(OfertaConsultaService ofertas) : ControllerBase
{
    /// <summary>Ofertas disponíveis agora, com busca, categoria e ordenação por distância.</summary>
    [HttpGet]
    public Task<PaginaDto<OfertaDto>> Listar([FromQuery] FiltroOfertas filtro, CancellationToken ct) =>
        ofertas.ListarAsync(filtro, ct);

    /// <summary>Detalhe de uma oferta. Latitude e longitude são opcionais, só para trazer a distância.</summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<OfertaDto>> Obter(int id, [FromQuery] double? latitude, [FromQuery] double? longitude,
        CancellationToken ct)
    {
        var oferta = await ofertas.ObterAsync(id, latitude, longitude, ct);
        return oferta is null ? NotFound() : oferta;
    }
}
