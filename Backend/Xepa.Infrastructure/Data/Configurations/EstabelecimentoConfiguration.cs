using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class EstabelecimentoConfiguration : IEntityTypeConfiguration<Estabelecimento>
{
    public void Configure(EntityTypeBuilder<Estabelecimento> builder)
    {
        builder.Property(e => e.Nome).HasMaxLength(120);
        builder.Property(e => e.Descricao).HasMaxLength(500);
        builder.Property(e => e.Cnpj).HasMaxLength(14).IsFixedLength();
        builder.Property(e => e.Telefone).HasMaxLength(20);
        builder.Property(e => e.LogoUrl).HasMaxLength(500);
        builder.ComplexProperty(e => e.Endereco, e => EnderecoMapeamento.Configurar(e));

        // Um usuário do tipo Estabelecimento tem exatamente um estabelecimento.
        builder.HasOne(e => e.Usuario)
            .WithOne(u => u.Estabelecimento)
            .HasForeignKey<Estabelecimento>(e => e.UsuarioId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(e => e.Cnpj).IsUnique();
        builder.HasIndex(e => e.Categoria);

        // Desativar a loja tira as ofertas do ar (trigger); o EF precisa saber para não usar OUTPUT.
        builder.ToTable(t => t.HasTrigger("trg_Estabelecimentos_Desativacao"));
    }
}
