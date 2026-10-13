using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Api.Entities;

namespace Xepa.Api.Data.Configurations;

public class OfertaConfiguration : IEntityTypeConfiguration<Oferta>
{
    public void Configure(EntityTypeBuilder<Oferta> builder)
    {
        builder.Property(o => o.Titulo).HasMaxLength(120);
        builder.Property(o => o.Descricao).HasMaxLength(1000);
        builder.Property(o => o.FotoUrl).HasMaxLength(500);
        builder.Property(o => o.PesoEstimadoKg).HasPrecision(6, 2);

        builder.HasOne(o => o.Estabelecimento)
            .WithMany(e => e.Ofertas)
            .HasForeignKey(o => o.EstabelecimentoId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.ToTable(t =>
        {
            t.HasCheckConstraint("CK_Ofertas_Preco", "[Preco] >= 0 AND [Preco] <= [PrecoOriginal]");
            t.HasCheckConstraint("CK_Ofertas_QuantidadeDisponivel", "[QuantidadeDisponivel] >= 0");
            t.HasCheckConstraint("CK_Ofertas_Retirada", "[RetiradaFim] > [RetiradaInicio]");
        });
    }
}
