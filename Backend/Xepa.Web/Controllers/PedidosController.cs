using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Web.Controllers;

/// <summary>Pedidos do dia da loja, com atualização em tempo real pelo SignalR da API.</summary>
[Route("pedidos")]
[Authorize(Roles = nameof(TipoUsuario.Estabelecimento))]
public class PedidosController(ApiXepa api, IConfiguration config) : Controller
{
    [HttpGet("")]
    public async Task<IActionResult> Index(CancellationToken ct)
    {
        // O navegador pode precisar de outro endereço que o servidor (ex.: docker compose).
        ViewData["UrlApi"] = (config["Api:UrlPublica"] ?? api.UrlBase.ToString()).TrimEnd('/');
        return View(await api.PedidosDaLojaAsync(ct));
    }

    /// <summary>Token novo para o SignalR do navegador (o de acesso dura 15 minutos).</summary>
    [HttpGet("token")]
    public IActionResult Token() => Json(new { token = api.TokenDoUsuario() });

    [HttpPost("{id:int}/status")]
    public Task<IActionResult> AlterarStatus(int id, StatusPedido status, CancellationToken ct) =>
        Executar(() => api.AlterarStatusAsync(id, status, ct), status switch
        {
            StatusPedido.Confirmado => $"Pedido #{id} aceito.",
            StatusPedido.Cancelado => $"Pedido #{id} recusado. O pagamento será estornado ao cliente.",
            StatusPedido.EmPreparo => $"Pedido #{id} em preparo.",
            _ => $"Pedido #{id} pronto para retirada."
        });

    [HttpPost("{id:int}/retirada")]
    public Task<IActionResult> ConfirmarRetirada(int id, string codigo, CancellationToken ct) =>
        Executar(() => api.ConfirmarRetiradaAsync(id, codigo ?? "", ct), $"Retirada do pedido #{id} confirmada.");

    private async Task<IActionResult> Executar(Func<Task> acao, string sucesso)
    {
        try
        {
            await acao();
            TempData["Mensagem"] = sucesso;
        }
        catch (Exception e) when (e is RegraDeNegocioException or NaoEncontradoException)
        {
            TempData["Erro"] = e.Message;
        }
        return RedirectToAction(nameof(Index));
    }
}
