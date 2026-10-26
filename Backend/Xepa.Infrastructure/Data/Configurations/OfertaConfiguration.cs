using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class OfertaConfiguration : IEntityTypeConfiguration<Oferta>
{
    public void Configure(EntityTypeBuilder<Oferta> builder)
    {
        builder.Property(o => o.Titulo).HasMaxLength(120);
        builder.Property(o => o.Descricao).HasMaxLength(1000);
        builder.Property(o => o.FotoUrl).HasMaxLength(500);
        builder.Property(o => o.PesoEstimadoKg).HasPrecision(6, 2);

        // Atende a listagem do app (RN01): ofertas ativas cuja janela ainda não terminou.
        builder.HasIndex(o => new { o.Ativa, o.RetiradaFim }, "IX_Ofertas_Listagem")
            .IncludeProperties(o => new { o.EstabelecimentoId, o.QuantidadeDisponivel, o.Preco, o.PrecoOriginal });

        builder.HasOne(o => o.Estabelecimento)
            .WithMany(e => e.Ofertas)
            .HasForeignKey(o => o.EstabelecimentoId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.ToTable(t =>
        {
            t.HasCheckConstraint("CK_Ofertas_Preco", "[Preco] > 0 AND [Preco] < [PrecoOriginal]");
            t.HasCheckConstraint("CK_Ofertas_QuantidadeDisponivel", "[QuantidadeDisponivel] >= 0");
            t.HasCheckConstraint("CK_Ofertas_Retirada", "[RetiradaFim] > [RetiradaInicio]");
            t.HasTrigger("trg_Ofertas_RemocaoLogica");
        });
    }
}
