namespace Xepa.Domain.Entities;

/// <summary>Mudança de status de um pedido. Gravado pelo trigger trg_Pedidos_Status, nunca pela aplicação.</summary>
public class PedidoHistoricoStatus
{
    public long Id { get; set; }
    public int PedidoId { get; set; }
    public StatusPedido? StatusAnterior { get; set; }
    public StatusPedido StatusNovo { get; set; }
    public DateTimeOffset AlteradoEm { get; set; }
}
