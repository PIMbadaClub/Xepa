using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class EnderecoUsuarioConfiguration : IEntityTypeConfiguration<EnderecoUsuario>
{
    public void Configure(EntityTypeBuilder<EnderecoUsuario> builder)
    {
        builder.Property(e => e.Apelido).HasMaxLength(40);
        builder.ComplexProperty(e => e.Endereco, e => EnderecoMapeamento.Configurar(e));

        builder.HasOne(e => e.Usuario)
            .WithMany(u => u.Enderecos)
            .HasForeignKey(e => e.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(e => e.UsuarioId);

        // No máximo um endereço principal por usuário.
        builder.HasIndex(e => e.UsuarioId, "IX_Enderecos_UsuarioId_Principal")
            .IsUnique()
            .HasFilter("[Principal] = 1");
    }
}
