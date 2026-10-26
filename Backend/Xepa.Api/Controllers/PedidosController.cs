using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application.Pagamentos;
using Xepa.Application.Pedidos;
using Xepa.Infrastructure.Seguranca;

namespace Xepa.Api.Controllers;

[ApiController]
[Route("api/pedidos")]
[Authorize(Roles = "Cliente")]
public class PedidosController(PedidoService pedidos, PagamentoService pagamentos) : ControllerBase
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
