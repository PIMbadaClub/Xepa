using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Api.Entities;

namespace Xepa.Api.Data.Configurations;

public class PedidoConfiguration : IEntityTypeConfiguration<Pedido>
{
    public void Configure(EntityTypeBuilder<Pedido> builder)
    {
        builder.Property(p => p.Observacao).HasMaxLength(500);
        builder.ComplexProperty(p => p.EnderecoEntrega, e => EnderecoMapeamento.Configurar(e, "Entrega"));

        // Restrict: pedido é histórico, não some quando cliente ou oferta são removidos.
        builder.HasOne(p => p.Cliente)
            .WithMany(u => u.Pedidos)
            .HasForeignKey(p => p.ClienteId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(p => p.Oferta)
            .WithMany(o => o.Pedidos)
            .HasForeignKey(p => p.OfertaId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(p => p.Status);

        builder.ToTable(t =>
        {
            t.HasCheckConstraint("CK_Pedidos_Quantidade", "[Quantidade] > 0");
            t.HasCheckConstraint("CK_Pedidos_EnderecoEntrega", "[TipoEntrega] <> 'Entrega' OR [EntregaLogradouro] IS NOT NULL");
        });
    }
}
