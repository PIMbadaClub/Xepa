namespace Xepa.Domain.Entities;

/// <summary>Posição do entregador durante a entrega; apagada 30 dias depois (RN09, LGPD).</summary>
public class RastreioEntrega
{
    public long Id { get; set; }
    public int PedidoId { get; set; }
    public Pedido Pedido { get; set; } = null!;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public DateTimeOffset RegistradoEm { get; set; }
}
