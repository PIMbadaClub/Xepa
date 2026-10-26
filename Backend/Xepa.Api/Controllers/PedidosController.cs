using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Api.Seguranca;
using Xepa.Application.Pedidos;

namespace Xepa.Api.Controllers;

[ApiController]
[Route("api/pedidos")]
[Authorize(Roles = "Cliente")]
public class PedidosController(PedidoService pedidos, IWebHostEnvironment env) : ControllerBase
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

    [HttpPost("{id:int}/cancelar")]
    public Task<PedidoDto> Cancelar(int id, CancellationToken ct) => pedidos.CancelarAsync(User.UsuarioId(), id, ct);

    /// <summary>Só em desenvolvimento: aprova o pagamento sem passar pelo gateway.</summary>
    [HttpPost("{id:int}/pagamento-simulado")]
    public async Task<ActionResult<PedidoDto>> SimularPagamento(int id, CancellationToken ct)
    {
        if (!env.IsDevelopment())
            return NotFound();
        return await pedidos.SimularPagamentoAsync(User.UsuarioId(), id, ct);
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
