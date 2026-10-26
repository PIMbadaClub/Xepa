using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application.Pagamentos;
using Xepa.Infrastructure.Integracoes;

namespace Xepa.Api.Controllers;

[ApiController]
[Route("api/pagamentos")]
public class PagamentosController(PagamentoService pagamentos, OpcoesMercadoPago opcoes, ILogger<PagamentosController> log)
    : ControllerBase
{
    /// <summary>
    /// Webhook do Mercado Pago. Valida a assinatura e consulta o pagamento na API do gateway antes de agir;
    /// o corpo da notificação nunca é usado como fonte da verdade.
    /// </summary>
    [HttpPost("webhook")]
    public async Task<IActionResult> Webhook([FromQuery(Name = "data.id")] string? dataId, [FromQuery] string? type,
        [FromBody] JsonElement? corpo, CancellationToken ct)
    {
        dataId ??= corpo is { ValueKind: JsonValueKind.Object } c && c.TryGetProperty("data", out var d)
                   && d.TryGetProperty("id", out var idJson) ? idJson.ToString() : null;
        type ??= corpo is { ValueKind: JsonValueKind.Object } c2 && c2.TryGetProperty("type", out var t) ? t.GetString() : null;

        if (string.IsNullOrEmpty(dataId) || type != "payment")
            return Ok(); // outros tópicos (ex.: merchant_order) não interessam

        if (!string.IsNullOrEmpty(opcoes.SegredoWebhook)
            && !GatewayMercadoPago.AssinaturaValida(opcoes.SegredoWebhook, Request.Headers["x-signature"],
                Request.Headers["x-request-id"], dataId))
        {
            log.LogWarning("Webhook com assinatura inválida para o pagamento {Id}.", dataId);
            return Unauthorized();
        }

        await pagamentos.ProcessarNotificacaoAsync(dataId, ct);
        return Ok();
    }

    /// <summary>Só em desenvolvimento: aprova uma cobrança do gateway simulado e dispara o mesmo fluxo do webhook.</summary>
    [HttpPost("simulado/{idExterno}/aprovar")]
    public async Task<IActionResult> AprovarSimulado(string idExterno, [FromServices] IServiceProvider sp,
        [FromServices] IWebHostEnvironment env, CancellationToken ct)
    {
        var simulado = sp.GetService<GatewaySimulado>();
        if (!env.IsDevelopment() || simulado is null)
            return NotFound();
        if (!simulado.Aprovar(idExterno))
            return NotFound();

        await pagamentos.ProcessarNotificacaoAsync(idExterno, ct);
        return NoContent();
    }
}
