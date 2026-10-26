using Xepa.Domain.Entities;

namespace Xepa.Application.Pagamentos;

public record Cobranca(string IdExterno, string? QrCodePix, string? UrlCheckout, DateTimeOffset? ExpiraEm);

/// <summary>Situação de um pagamento consultada no gateway (nunca confiamos só no corpo do webhook).</summary>
public record SituacaoPagamento(string IdExterno, StatusPagamento Status, int? PedidoId, decimal Valor,
    MetodoPagamento Metodo, DateTimeOffset? AprovadoEm);

/// <summary>Gateway de pagamento. Produção: Mercado Pago; desenvolvimento: simulado.</summary>
public interface IGatewayPagamento
{
    string Provedor { get; }

    Task<Cobranca> CriarCobrancaAsync(Pedido pedido, MetodoPagamento metodo, string emailPagador, CancellationToken ct);

    Task<SituacaoPagamento?> ConsultarAsync(string idExterno, CancellationToken ct);

    Task EstornarAsync(string idExterno, CancellationToken ct);
}

/// <summary>Aprova o pagamento e libera o pedido para a loja numa transação (procedure sp_ConfirmarPagamento).</summary>
public interface IConfirmacaoPagamento
{
    Task ConfirmarAsync(string provedor, string idExterno, DateTimeOffset pagoEm, CancellationToken ct);
}

/// <summary>Avisos em tempo real (SignalR) para o app do cliente, do entregador e o portal da loja.</summary>
public interface INotificadorPedidos
{
    Task PedidoAlteradoAsync(int pedidoId, CancellationToken ct);
    Task PosicaoEntregadorAsync(int pedidoId, double latitude, double longitude, CancellationToken ct);
}

/// <summary>Usado onde não há canal em tempo real (portal, testes).</summary>
public class NotificadorNulo : INotificadorPedidos
{
    public Task PedidoAlteradoAsync(int pedidoId, CancellationToken ct) => Task.CompletedTask;
    public Task PosicaoEntregadorAsync(int pedidoId, double latitude, double longitude, CancellationToken ct) => Task.CompletedTask;
}
