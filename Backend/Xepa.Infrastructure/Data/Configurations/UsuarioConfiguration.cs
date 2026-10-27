using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class UsuarioConfiguration : IEntityTypeConfiguration<Usuario>
{
    public void Configure(EntityTypeBuilder<Usuario> builder)
    {
        builder.Property(u => u.Nome).HasMaxLength(120);
        builder.Property(u => u.Email).HasMaxLength(254);
        builder.Property(u => u.SenhaHash).HasMaxLength(200);
        builder.Property(u => u.Telefone).HasMaxLength(20);
        builder.Property(u => u.Placa).HasMaxLength(8);
        builder.Property(u => u.ModeloMoto).HasMaxLength(60);
        builder.Property(u => u.GoogleId).HasMaxLength(64);
        builder.HasIndex(u => u.GoogleId).IsUnique().HasFilter("[GoogleId] IS NOT NULL");

        builder.HasIndex(u => u.Email).IsUnique();
    }
}
