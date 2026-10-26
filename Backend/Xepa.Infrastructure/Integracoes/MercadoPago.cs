using System.Collections.Concurrent;
using System.Globalization;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Xepa.Application.Pagamentos;
using Xepa.Domain.Entities;
using Xepa.Infrastructure.Data;

namespace Xepa.Infrastructure.Integracoes;

public class OpcoesMercadoPago
{
    public const string Secao = "MercadoPago";

    /// <summary>Access token (de teste ou produção). Vazio = gateway simulado.</summary>
    public string? AccessToken { get; init; }

    /// <summary>Assinatura secreta do webhook, usada para validar o cabeçalho x-signature.</summary>
    public string? SegredoWebhook { get; init; }

    /// <summary>URL pública do webhook (ex.: https://xepa-api.azurewebsites.net/api/pagamentos/webhook).</summary>
    public string? UrlNotificacao { get; init; }

    /// <summary>Para onde o checkout de cartão volta ao terminar (página simples ou deep link do app).</summary>
    public string? UrlRetorno { get; init; }

    public int MinutosValidadePix { get; init; } = 15;

    public bool Configurado => !string.IsNullOrWhiteSpace(AccessToken);
}

/// <summary>
/// Integração com a API do Mercado Pago: Pix pela API de pagamentos e cartão pelo Checkout Pro
/// (a página do gateway recebe o cartão; os dados nunca passam pela XEPA).
/// </summary>
public class GatewayMercadoPago(HttpClient http, OpcoesMercadoPago opcoes) : IGatewayPagamento
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public string Provedor => Pagamento.MercadoPago;

    public async Task<Cobranca> CriarCobrancaAsync(Pedido pedido, MetodoPagamento metodo, string emailPagador, CancellationToken ct)
    {
        var descricao = $"XEPA pedido {pedido.Id}: {pedido.Quantidade}x {pedido.Oferta.Titulo}";
        if (metodo == MetodoPagamento.Pix)
        {
            var expira = DateTimeOffset.UtcNow.AddMinutes(opcoes.MinutosValidadePix);
            var corpo = new
            {
                TransactionAmount = pedido.ValorTotal,
                Description = descricao,
                PaymentMethodId = "pix",
                ExternalReference = pedido.Id.ToString(CultureInfo.InvariantCulture),
                NotificationUrl = opcoes.UrlNotificacao,
                DateOfExpiration = expira.ToOffset(TimeSpan.FromHours(-3)).ToString("yyyy-MM-dd'T'HH:mm:ss.fffzzz", CultureInfo.InvariantCulture),
                Payer = new { Email = emailPagador }
            };
            using var resp = await EnviarAsync(HttpMethod.Post, "v1/payments", corpo, ct);
            var pagamento = await resp.Content.ReadFromJsonAsync<RespostaPagamento>(Json, ct);
            return new Cobranca(pagamento!.Id.ToString(CultureInfo.InvariantCulture),
                pagamento.PointOfInteraction?.TransactionData?.QrCode, pagamento.PointOfInteraction?.TransactionData?.TicketUrl, expira);
        }

        var preferencia = new
        {
            Items = new[] { new { Title = descricao, Quantity = 1, UnitPrice = pedido.ValorTotal, CurrencyId = "BRL" } },
            ExternalReference = pedido.Id.ToString(CultureInfo.InvariantCulture),
            NotificationUrl = opcoes.UrlNotificacao,
            PaymentMethods = new { ExcludedPaymentTypes = new[] { new { Id = "ticket" } }, Installments = 1 },
            BackUrls = opcoes.UrlRetorno is null ? null : new { Success = opcoes.UrlRetorno, Failure = opcoes.UrlRetorno, Pending = opcoes.UrlRetorno },
            AutoReturn = opcoes.UrlRetorno is null ? null : "approved",
            ExpirationDateTo = DateTimeOffset.UtcNow.AddMinutes(15).ToString("yyyy-MM-dd'T'HH:mm:ss.fffzzz", CultureInfo.InvariantCulture),
            Expires = true
        };
        using var r = await EnviarAsync(HttpMethod.Post, "checkout/preferences", preferencia, ct);
        var pref = await r.Content.ReadFromJsonAsync<RespostaPreferencia>(Json, ct);
        var url = opcoes.AccessToken!.StartsWith("TEST-", StringComparison.Ordinal) ? pref!.SandboxInitPoint : pref!.InitPoint;
        return new Cobranca(pref.Id, null, url, DateTimeOffset.UtcNow.AddMinutes(15));
    }

    public async Task<SituacaoPagamento?> ConsultarAsync(string idExterno, CancellationToken ct)
    {
        using var resp = await EnviarAsync(HttpMethod.Get, $"v1/payments/{Uri.EscapeDataString(idExterno)}", null, ct, aceitar404: true);
        if (resp.StatusCode == System.Net.HttpStatusCode.NotFound)
            return null;

        var p = await resp.Content.ReadFromJsonAsync<RespostaPagamento>(Json, ct);
        var status = p!.Status switch
        {
            "approved" => StatusPagamento.Aprovado,
            "rejected" or "cancelled" => StatusPagamento.Recusado,
            "refunded" or "charged_back" => StatusPagamento.Estornado,
            _ => StatusPagamento.Pendente
        };
        int? pedidoId = int.TryParse(p.ExternalReference, out var id) ? id : null;
        var metodo = p.PaymentMethodId == "pix" ? MetodoPagamento.Pix : MetodoPagamento.Cartao;
        return new SituacaoPagamento(p.Id.ToString(CultureInfo.InvariantCulture), status, pedidoId, p.TransactionAmount, metodo, p.DateApproved);
    }

    public async Task EstornarAsync(string idExterno, CancellationToken ct)
    {
        using var _ = await EnviarAsync(HttpMethod.Post, $"v1/payments/{Uri.EscapeDataString(idExterno)}/refunds", new { }, ct);
    }

    /// <summary>
    /// Valida o cabeçalho x-signature do webhook: HMAC-SHA256 de "id:{data.id};request-id:{x-request-id};ts:{ts};"
    /// com a assinatura secreta configurada no painel do Mercado Pago.
    /// </summary>
    public static bool AssinaturaValida(string segredo, string? xSignature, string? xRequestId, string dataId)
    {
        if (string.IsNullOrEmpty(xSignature))
            return false;

        var partes = xSignature.Split(',', StringSplitOptions.TrimEntries)
            .Select(p => p.Split('=', 2))
            .Where(p => p.Length == 2)
            .ToDictionary(p => p[0], p => p[1]);
        if (!partes.TryGetValue("ts", out var ts) || !partes.TryGetValue("v1", out var v1))
            return false;

        var manifesto = $"id:{dataId.ToLowerInvariant()};";
        if (!string.IsNullOrEmpty(xRequestId))
            manifesto += $"request-id:{xRequestId};";
        manifesto += $"ts:{ts};";

        var esperado = Convert.ToHexStringLower(HMACSHA256.HashData(Encoding.UTF8.GetBytes(segredo), Encoding.UTF8.GetBytes(manifesto)));
        return CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(esperado), Encoding.ASCII.GetBytes(v1.ToLowerInvariant()));
    }

    private async Task<HttpResponseMessage> EnviarAsync(HttpMethod metodo, string caminho, object? corpo, CancellationToken ct,
        bool aceitar404 = false)
    {
        using var req = new HttpRequestMessage(metodo, caminho);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", opcoes.AccessToken);
        if (metodo == HttpMethod.Post)
            req.Headers.Add("X-Idempotency-Key", Guid.NewGuid().ToString());
        if (corpo is not null)
            req.Content = JsonContent.Create(corpo, options: Json);

        var resp = await http.SendAsync(req, ct);
        if (resp.IsSuccessStatusCode || (aceitar404 && resp.StatusCode == System.Net.HttpStatusCode.NotFound))
            return resp;

        var erro = await resp.Content.ReadAsStringAsync(ct);
        resp.Dispose();
        throw new InvalidOperationException($"Mercado Pago respondeu {(int)resp.StatusCode} em {caminho}: {erro}");
    }

    private record RespostaPagamento(long Id, string Status, string? ExternalReference, decimal TransactionAmount,
        string? PaymentMethodId, DateTimeOffset? DateApproved, PontoDeInteracao? PointOfInteraction);

    private record PontoDeInteracao(DadosTransacao? TransactionData);

    private record DadosTransacao(string? QrCode, string? QrCodeBase64, string? TicketUrl);

    private record RespostaPreferencia(string Id, string? InitPoint, string? SandboxInitPoint);
}

/// <summary>
/// Gateway de desenvolvimento: gera um Pix de mentira e guarda o estado em memória.
/// O pagamento é aprovado pelo endpoint de simulação, que segue o mesmo caminho do webhook real.
/// </summary>
public class GatewaySimulado : IGatewayPagamento
{
    private readonly ConcurrentDictionary<string, SituacaoPagamento> pagamentos = new();

    public string Provedor => Pagamento.Simulado;

    public Task<Cobranca> CriarCobrancaAsync(Pedido pedido, MetodoPagamento metodo, string emailPagador, CancellationToken ct)
    {
        var id = $"SIM-{Guid.NewGuid():N}"[..20];
        pagamentos[id] = new SituacaoPagamento(id, StatusPagamento.Pendente, pedido.Id, pedido.ValorTotal, metodo, null);
        var pix = metodo == MetodoPagamento.Pix
            ? $"00020126580014BR.GOV.BCB.PIX0136XEPA-SIMULADO-{id}5204000053039865406{pedido.ValorTotal.ToString("0.00", CultureInfo.InvariantCulture)}5802BR5904XEPA6007LIMEIRA62070503***6304ABCD"
            : null;
        return Task.FromResult(new Cobranca(id, pix, null, DateTimeOffset.UtcNow.AddMinutes(15)));
    }

    public Task<SituacaoPagamento?> ConsultarAsync(string idExterno, CancellationToken ct) =>
        Task.FromResult(pagamentos.TryGetValue(idExterno, out var s) ? s : null);

    public Task EstornarAsync(string idExterno, CancellationToken ct)
    {
        if (pagamentos.TryGetValue(idExterno, out var s))
            pagamentos[idExterno] = s with { Status = StatusPagamento.Estornado };
        return Task.CompletedTask;
    }

    /// <summary>Marca como pago, como se o cliente tivesse pagado no banco.</summary>
    public bool Aprovar(string idExterno)
    {
        if (!pagamentos.TryGetValue(idExterno, out var s))
            return false;
        pagamentos[idExterno] = s with { Status = StatusPagamento.Aprovado, AprovadoEm = DateTimeOffset.UtcNow };
        return true;
    }
}

/// <summary>Chama sp_ConfirmarPagamento: aprova o pagamento e libera o pedido na mesma transação.</summary>
public class ConfirmacaoPagamentoSql(XepaDbContext db) : IConfirmacaoPagamento
{
    public Task ConfirmarAsync(string provedor, string idExterno, DateTimeOffset pagoEm, CancellationToken ct) =>
        db.Database.ExecuteSqlRawAsync("EXEC dbo.sp_ConfirmarPagamento @Provedor, @IdExterno, @PagoEm",
        [
            new SqlParameter("@Provedor", provedor),
            new SqlParameter("@IdExterno", idExterno),
            new SqlParameter("@PagoEm", pagoEm)
        ], ct);
}
