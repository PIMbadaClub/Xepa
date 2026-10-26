using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application.Ofertas;
using Xepa.Application.Pagamentos;
using Xepa.Application.Pedidos;
using Xepa.Infrastructure.Seguranca;

namespace Xepa.Api.Controllers;

[ApiController]
[Route("api/pedidos")]
[Authorize(Roles = "Cliente")]
public class PedidosController(PedidoService pedidos, PagamentoService pagamentos, DenunciaService denuncias) : ControllerBase
{
    /// <summary>Cria o pedido reservando o estoque; fica AguardandoPagamento por até 15 minutos.</summary>
    [HttpPost]
    public async Task<ActionResult<PedidoDto>> Criar(CriarPedidoRequest request, CancellationToken ct)
    {
        var pedido = await pedidos.CriarAsync(User.UsuarioId(), request, ct);
        return CreatedAtAction(nameof(Obter), new { id = pedido.Id }, pedido);
    }

    [HttpGet]
    public Task<IReadOnlyList<PedidoDto>> Listar(CancellationToken ct) => pedidos.ListarDoClienteAsync(User.UsuarioId(), ct);

    [HttpGet("{id:int}")]
    public Task<PedidoDto> Obter(int id, CancellationToken ct) => pedidos.ObterDoClienteAsync(User.UsuarioId(), id, ct);

    /// <summary>Cancela antes da confirmação da loja; estorna o pagamento se já foi aprovado.</summary>
    [HttpPost("{id:int}/cancelar")]
    public Task<PedidoDto> Cancelar(int id, CancellationToken ct) => pedidos.CancelarAsync(User.UsuarioId(), id, ct);

    /// <summary>Gera a cobrança: Pix devolve o código copia e cola; cartão devolve a página do checkout.</summary>
    [HttpPost("{id:int}/pagamento")]
    public Task<PagamentoDto> Pagar(int id, IniciarPagamentoRequest request, CancellationToken ct) =>
        pagamentos.IniciarAsync(User.UsuarioId(), id, request.Metodo, ct);

    [HttpGet("{id:int}/pagamentos")]
    public Task<IReadOnlyList<PagamentoDto>> Pagamentos(int id, CancellationToken ct) =>
        pagamentos.ListarDoPedidoAsync(User.UsuarioId(), id, ct);

    /// <summary>Posições para o mapa: loja, destino e última posição do entregador.</summary>
    [HttpGet("{id:int}/rastreio")]
    public Task<RastreioDto> Rastreio(int id, CancellationToken ct) => pedidos.ObterRastreioAsync(User.UsuarioId(), id, ct);

    /// <summary>Canal de denúncia do pedido; tratado pela equipe da XEPA no portal administrativo.</summary>
    [HttpPost("{id:int}/denuncias")]
    public async Task<ActionResult<DenunciaDto>> Denunciar(int id, CriarDenunciaRequest request, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created, await denuncias.CriarAsync(User.UsuarioId(), id, request, ct));

    [HttpGet("{id:int}/denuncias")]
    public Task<IReadOnlyList<DenunciaDto>> Denuncias(int id, CancellationToken ct) =>
        denuncias.ListarDoPedidoAsync(User.UsuarioId(), id, ct);
}

/// <summary>Lojas favoritas do cliente (RF10).</summary>
[ApiController]
[Route("api/favoritos")]
[Authorize(Roles = "Cliente")]
public class FavoritosController(FavoritoService favoritos) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<LojaFavoritaDto>> Listar(CancellationToken ct) => favoritos.ListarAsync(User.UsuarioId(), ct);

    /// <summary>Só os ids, para o app marcar o coração nas ofertas.</summary>
    [HttpGet("ids")]
    public Task<IReadOnlyList<int>> Ids(CancellationToken ct) => favoritos.IdsAsync(User.UsuarioId(), ct);

    [HttpPut("{estabelecimentoId:int}")]
    public async Task<IActionResult> Adicionar(int estabelecimentoId, CancellationToken ct)
    {
        await favoritos.AdicionarAsync(User.UsuarioId(), estabelecimentoId, ct);
        return NoContent();
    }

    [HttpDelete("{estabelecimentoId:int}")]
    public async Task<IActionResult> Remover(int estabelecimentoId, CancellationToken ct)
    {
        await favoritos.RemoverAsync(User.UsuarioId(), estabelecimentoId, ct);
        return NoContent();
    }
}

[ApiController]
[Route("api/enderecos")]
[Authorize(Roles = "Cliente")]
public class EnderecosController(EnderecoService enderecos) : ControllerBase
{
    [HttpGet]
    public Task<IReadOnlyList<EnderecoDto>> Listar(CancellationToken ct) => enderecos.ListarAsync(User.UsuarioId(), ct);

    [HttpPost]
    public async Task<ActionResult<EnderecoDto>> Criar(EnderecoRequest request, CancellationToken ct) =>
        StatusCode(StatusCodes.Status201Created, await enderecos.CriarAsync(User.UsuarioId(), request, ct));

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Excluir(int id, CancellationToken ct)
    {
        await enderecos.ExcluirAsync(User.UsuarioId(), id, ct);
        return NoContent();
    }
}
