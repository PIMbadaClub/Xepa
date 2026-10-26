namespace Xepa.Domain.Entities;

/// <summary>Cobrança de um pedido no gateway. Um pedido pode ter mais de uma tentativa.</summary>
public class Pagamento : Entidade
{
    public const string MercadoPago = "MercadoPago";

    public int PedidoId { get; set; }
    public Pedido Pedido { get; set; } = null!;

    public string Provedor { get; set; } = MercadoPago;

    /// <summary>Identificador do pagamento no gateway; é por ele que o webhook encontra o registro.</summary>
    public required string IdExterno { get; set; }

    public MetodoPagamento Metodo { get; set; }
    public StatusPagamento Status { get; set; } = StatusPagamento.Pendente;
    public decimal Valor { get; set; }

    /// <summary>Código "copia e cola" do Pix.</summary>
    public string? QrCodePix { get; set; }

    public DateTimeOffset? PagoEm { get; set; }
}
