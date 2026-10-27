using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class DispositivoPushConfiguration : IEntityTypeConfiguration<DispositivoPush>
{
    public void Configure(EntityTypeBuilder<DispositivoPush> builder)
    {
        builder.Property(d => d.Token).HasMaxLength(512).IsRequired();
        builder.Property(d => d.Plataforma).HasMaxLength(20).IsRequired();
        builder.HasOne(d => d.Usuario).WithMany().HasForeignKey(d => d.UsuarioId).OnDelete(DeleteBehavior.Cascade);
        // O mesmo aparelho pode trocar de conta: o token é único e passa para quem entrou por último.
        builder.HasIndex(d => d.Token).IsUnique();
        builder.HasIndex(d => d.UsuarioId);
    }
}
