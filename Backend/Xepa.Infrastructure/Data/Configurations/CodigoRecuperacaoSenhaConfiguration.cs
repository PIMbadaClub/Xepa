using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class CodigoRecuperacaoSenhaConfiguration : IEntityTypeConfiguration<CodigoRecuperacaoSenha>
{
    public void Configure(EntityTypeBuilder<CodigoRecuperacaoSenha> builder)
    {
        builder.ToTable("CodigosRecuperacaoSenha");
        builder.Property(c => c.CodigoHash).HasMaxLength(64);
        builder.HasIndex(c => new { c.UsuarioId, c.UsadoEm });

        builder.HasOne(c => c.Usuario)
            .WithMany()
            .HasForeignKey(c => c.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
