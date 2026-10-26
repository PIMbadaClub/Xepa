using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class RepasseConfiguration : IEntityTypeConfiguration<Repasse>
{
    public void Configure(EntityTypeBuilder<Repasse> builder)
    {
        builder.Ignore(r => r.Pago);

        builder.HasOne(r => r.Estabelecimento).WithMany().HasForeignKey(r => r.EstabelecimentoId).OnDelete(DeleteBehavior.Restrict);
        builder.HasMany(r => r.Pedidos).WithOne(p => p.Repasse).HasForeignKey(p => p.RepasseId).OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(r => new { r.EstabelecimentoId, r.CriadoEm });
    }
}
