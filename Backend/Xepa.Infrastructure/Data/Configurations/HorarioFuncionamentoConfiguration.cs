using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class HorarioFuncionamentoConfiguration : IEntityTypeConfiguration<HorarioFuncionamento>
{
    public void Configure(EntityTypeBuilder<HorarioFuncionamento> builder)
    {
        builder.ToTable("HorariosFuncionamento");
        builder.HasIndex(h => new { h.EstabelecimentoId, h.DiaSemana }).IsUnique();
        builder.HasOne<Estabelecimento>().WithMany(e => e.Horarios).HasForeignKey(h => h.EstabelecimentoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
