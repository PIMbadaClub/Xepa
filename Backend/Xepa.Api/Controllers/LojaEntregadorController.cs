using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application.Pedidos;
using Xepa.Infrastructure.Integracoes;
using Xepa.Infrastructure.Seguranca;

namespace Xepa.Api.Controllers;

/// <summary>Pedidos recebidos pela loja (usado pelo portal web).</summary>
[ApiController]
[Route("api/estabelecimento/pedidos")]
[Authorize(Roles = "Estabelecimento")]
public class EstabelecimentoPedidosController(PedidoLojaService pedidos) : ControllerBase
{
    private int Loja => int.Parse(User.FindFirst(GeradorTokenJwt.ClaimEstabelecimento)!.Value);

    [HttpGet]
    public Task<IReadOnlyList<PedidoLojaDto>> Listar(CancellationToken ct) => pedidos.ListarAsync(Loja, ct);

    /// <summary>Aceitar (Confirmado), preparar, pronto, ou recusar (Cancelado, com estorno).</summary>
    [HttpPatch("{id:int}/status")]
    public async Task<IActionResult> AlterarStatus(int id, AlterarStatusRequest request, CancellationToken ct)
    {
        await pedidos.AlterarStatusAsync(Loja, id, request.Status, ct);
        return NoContent();
    }

    [HttpPost("{id:int}/retirada")]
    public async Task<IActionResult> ConfirmarRetirada(int id, ConfirmarRetiradaRequest request, CancellationToken ct)
    {
        await pedidos.ConfirmarRetiradaAsync(Loja, id, request.Codigo, ct);
        return NoContent();
    }
}

public class PosicaoRequest
{
    [Range(-90, 90)]
    public double Latitude { get; init; }

    [Range(-180, 180)]
    public double Longitude { get; init; }
}

/// <summary>Modo entregador do app.</summary>
[ApiController]
[Route("api/entregador/entregas")]
[Authorize(Roles = "Entregador")]
public class EntregadorController(EntregaService entregas) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<EntregaService.EntregaDto>> Listar(CancellationToken ct) => entregas.ListarAsync(User.UsuarioId(), ct);

    [HttpPost("{id:int}/iniciar")]
    public async Task<IActionResult> Iniciar(int id, CancellationToken ct)
    {
        await entregas.IniciarAsync(User.UsuarioId(), id, ct);
        return NoContent();
    }

    [HttpPost("{id:int}/localizacao")]
    public async Task<IActionResult> Localizacao(int id, PosicaoRequest request, CancellationToken ct)
    {
        await entregas.RegistrarPosicaoAsync(User.UsuarioId(), id, request.Latitude, request.Longitude, ct);
        return NoContent();
    }

    [HttpPost("{id:int}/concluir")]
    public async Task<IActionResult> Concluir(int id, CancellationToken ct)
    {
        await entregas.ConcluirAsync(User.UsuarioId(), id, ct);
        return NoContent();
    }
}

/// <summary>Configuração do mapa para o app: Azure Maps quando há chave, OpenStreetMap em desenvolvimento.</summary>
[ApiController]
[Route("api/mapas")]
public class MapasController(OpcoesMapas opcoes) : ControllerBase
{
    public record ConfigMapaDto(string UrlTiles, string Atribuicao, int ZoomMaximo);

    [HttpGet("config")]
    public ConfigMapaDto Config() => opcoes.AzureConfigurado
        ? new ConfigMapaDto(
            "https://atlas.microsoft.com/map/tile?api-version=2024-04-01&tilesetId=microsoft.base.road&zoom={z}&x={x}&y={y}&tileSize=256&language=pt-BR&subscription-key=" + opcoes.AzureMapsChave,
            "© Microsoft Azure Maps", 19)
        : new ConfigMapaDto("https://tile.openstreetmap.org/{z}/{x}/{y}.png", "© colaboradores do OpenStreetMap", 19);
}
