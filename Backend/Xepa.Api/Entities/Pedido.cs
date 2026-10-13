namespace Xepa.Api.Entities;

public class Pedido : Entidade
{
    public int ClienteId { get; set; }
    public Usuario Cliente { get; set; } = null!;

    public int OfertaId { get; set; }
    public Oferta Oferta { get; set; } = null!;

    public int Quantidade { get; set; }

    /// <summary>Preço da oferta no momento do pedido; não muda se o restaurante alterar a oferta depois.</summary>
    public decimal PrecoUnitario { get; set; }
    public decimal TaxaEntrega { get; set; }
    public decimal ValorTotal { get; set; }

    public TipoEntrega TipoEntrega { get; set; }

    /// <summary>
    /// Cópia do endereço no momento do pedido (só quando TipoEntrega = Entrega),
    /// para o histórico não mudar se o cliente editar ou apagar o endereço.
    /// </summary>
    public Endereco? EnderecoEntrega { get; set; }

    public StatusPedido Status { get; set; } = StatusPedido.Pendente;
    public string? Observacao { get; set; }
}
