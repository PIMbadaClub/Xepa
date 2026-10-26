namespace Xepa.Domain.Entities;

/// <summary>Cobrança de um pedido no gateway. Um pedido pode ter mais de uma tentativa.</summary>
public class Pagamento : Entidade
{
    public const string MercadoPago = "MercadoPago";
    public const string Simulado = "Simulado";

    public int PedidoId { get; set; }
    public Pedido Pedido { get; set; } = null!;

    public string Provedor { get; set; } = MercadoPago;

    /// <summary>
    /// Identificador no gateway; é por ele que o webhook encontra o registro. No cartão começa com o id
    /// da preferência do checkout e passa a ser o id do pagamento quando o gateway notifica.
    /// </summary>
    public required string IdExterno { get; set; }

    public MetodoPagamento Metodo { get; set; }
    public StatusPagamento Status { get; set; } = StatusPagamento.Pendente;
    public decimal Valor { get; set; }

    /// <summary>Código "copia e cola" do Pix; o app desenha o QR Code a partir dele.</summary>
    public string? QrCodePix { get; set; }

    /// <summary>Página de pagamento com cartão do gateway (o número do cartão nunca passa pela XEPA).</summary>
    public string? UrlCheckout { get; set; }

    public DateTimeOffset? ExpiraEm { get; set; }
    public DateTimeOffset? PagoEm { get; set; }

    public bool Vigente(DateTimeOffset agora) =>
        Status == StatusPagamento.Pendente && (ExpiraEm is null || ExpiraEm > agora);

    public void Aprovar(DateTimeOffset pagoEm)
    {
        if (Status is StatusPagamento.Aprovado or StatusPagamento.Estornado)
            return; // notificação repetida
        Status = StatusPagamento.Aprovado;
        PagoEm = pagoEm;
    }

    public void Recusar()
    {
        if (Status == StatusPagamento.Pendente)
            Status = StatusPagamento.Recusado;
    }

    public void MarcarEstornado()
    {
        if (Status != StatusPagamento.Aprovado)
            throw new RegraDeNegocioException("Só um pagamento aprovado pode ser estornado.");
        Status = StatusPagamento.Estornado;
    }
}
