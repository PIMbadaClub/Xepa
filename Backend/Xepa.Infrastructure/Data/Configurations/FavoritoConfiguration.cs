using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class FavoritoConfiguration : IEntityTypeConfiguration<Favorito>
{
    public void Configure(EntityTypeBuilder<Favorito> builder)
    {
        builder.HasKey(f => new { f.UsuarioId, f.EstabelecimentoId });

        builder.HasOne(f => f.Usuario)
            .WithMany(u => u.Favoritos)
            .HasForeignKey(f => f.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(f => f.Estabelecimento)
            .WithMany()
            .HasForeignKey(f => f.EstabelecimentoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
