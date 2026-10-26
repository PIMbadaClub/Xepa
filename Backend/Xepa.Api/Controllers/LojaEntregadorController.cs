using Xepa.Application;
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

public class ConcluirEntregaRequest
{
    [Required(ErrorMessage = "Informe o código do cliente."), RegularExpression(@"^\d{4}$", ErrorMessage = "O código tem 4 dígitos.")]
    public required string Codigo { get; init; }
}

/// <summary>Modo entregador do app: corridas perto, aceitar, coletar, posição e finalizar com o código do cliente.</summary>
[ApiController]
[Route("api/entregador")]
[Authorize(Roles = "Entregador")]
public class EntregadorController(EntregaService entregas) : ControllerBase
{
    /// <summary>Corridas disponíveis perto (latitude/longitude do aparelho) e as aceitas por este entregador.</summary>
    [HttpGet("corridas")]
    public Task<IReadOnlyList<CorridaDto>> Corridas(double? latitude, double? longitude, CancellationToken ct) =>
        entregas.ListarAsync(User.UsuarioId(), Posicao(latitude, longitude), ct);

    [HttpGet("corridas/{id:int}/rota")]
    public Task<RotaCorridaDto> Rota(int id, double? latitude, double? longitude, CancellationToken ct) =>
        entregas.RotaAsync(User.UsuarioId(), id, Posicao(latitude, longitude), ct);

    [HttpPost("corridas/{id:int}/aceitar")]
    public Task<IActionResult> Aceitar(int id, CancellationToken ct) => Fazer(() => entregas.AceitarAsync(User.UsuarioId(), id, ct));

    [HttpPost("corridas/{id:int}/desistir")]
    public Task<IActionResult> Desistir(int id, CancellationToken ct) => Fazer(() => entregas.DesistirAsync(User.UsuarioId(), id, ct));

    [HttpPost("corridas/{id:int}/coletar")]
    public Task<IActionResult> Coletar(int id, CancellationToken ct) => Fazer(() => entregas.ColetarAsync(User.UsuarioId(), id, ct));

    [HttpPost("corridas/{id:int}/localizacao")]
    public Task<IActionResult> Localizacao(int id, PosicaoRequest request, CancellationToken ct) =>
        Fazer(() => entregas.RegistrarPosicaoAsync(User.UsuarioId(), id, request.Latitude, request.Longitude, ct));

    [HttpPost("corridas/{id:int}/concluir")]
    public Task<IActionResult> Concluir(int id, ConcluirEntregaRequest request, CancellationToken ct) =>
        Fazer(() => entregas.ConcluirAsync(User.UsuarioId(), id, request.Codigo, ct));

    [HttpGet("ganhos")]
    public Task<GanhosDto> Ganhos(CancellationToken ct) => entregas.GanhosAsync(User.UsuarioId(), ct);

    /// <summary>Fica online (recebe corridas) ou offline.</summary>
    [HttpPut("online")]
    public async Task<OnlineDto> Online(OnlineDto request, CancellationToken ct) =>
        new(await entregas.DefinirOnlineAsync(User.UsuarioId(), request.Online, ct));

    [HttpGet("perfil")]
    public Task<PerfilEntregadorDto> Perfil(CancellationToken ct) => entregas.PerfilAsync(User.UsuarioId(), ct);

    [HttpPut("perfil")]
    public Task<PerfilEntregadorDto> AtualizarPerfil(AtualizarPerfilEntregadorRequest request, CancellationToken ct) =>
        entregas.AtualizarPerfilAsync(User.UsuarioId(), request, ct);

    public record OnlineDto(bool Online);

    private static Coordenada? Posicao(double? latitude, double? longitude) =>
        latitude is { } la && longitude is { } lo && Math.Abs(la) <= 90 && Math.Abs(lo) <= 180 ? new Coordenada(la, lo) : null;

    private async Task<IActionResult> Fazer(Func<Task> acao)
    {
        await acao();
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
