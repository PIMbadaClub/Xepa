using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class RepasseEntregadorConfiguration : IEntityTypeConfiguration<RepasseEntregador>
{
    public void Configure(EntityTypeBuilder<RepasseEntregador> builder)
    {
        builder.ToTable("RepassesEntregadores");
        builder.Ignore(r => r.Pago);

        builder.HasOne(r => r.Entregador).WithMany().HasForeignKey(r => r.EntregadorId).OnDelete(DeleteBehavior.Restrict);
        builder.HasMany(r => r.Pedidos).WithOne(p => p.RepasseEntregador).HasForeignKey(p => p.RepasseEntregadorId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(r => new { r.EntregadorId, r.CriadoEm });
    }
}
