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

        builder.HasIndex(u => u.Email).IsUnique();
    }
}
