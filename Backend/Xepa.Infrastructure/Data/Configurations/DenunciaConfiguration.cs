using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class DenunciaConfiguration : IEntityTypeConfiguration<Denuncia>
{
    public void Configure(EntityTypeBuilder<Denuncia> builder)
    {
        builder.Property(d => d.Descricao).HasMaxLength(1000).IsRequired();
        builder.Property(d => d.Resposta).HasMaxLength(1000);

        builder.HasOne(d => d.Pedido).WithMany().HasForeignKey(d => d.PedidoId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(d => d.Autor).WithMany().HasForeignKey(d => d.AutorId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(d => d.TratadaPor).WithMany().HasForeignKey(d => d.TratadaPorId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(d => d.Estabelecimento).WithMany().HasForeignKey(d => d.EstabelecimentoId).OnDelete(DeleteBehavior.Restrict);

        // Fila do atendimento: abertas primeiro, das mais antigas para as mais novas.
        builder.HasIndex(d => new { d.Status, d.CriadoEm });
        // Uma denúncia em aberto por pedido.
        builder.HasIndex(d => d.PedidoId).IsUnique().HasFilter("[Status] = 'Aberta'");
    }
}
