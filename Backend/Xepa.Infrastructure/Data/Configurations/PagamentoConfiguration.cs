using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class PagamentoConfiguration : IEntityTypeConfiguration<Pagamento>
{
    public void Configure(EntityTypeBuilder<Pagamento> builder)
    {
        builder.Property(p => p.Provedor).HasMaxLength(30);
        builder.Property(p => p.IdExterno).HasMaxLength(60);
        builder.Property(p => p.UrlCheckout).HasMaxLength(500);

        builder.HasOne(p => p.Pedido)
            .WithMany(p => p.Pagamentos)
            .HasForeignKey(p => p.PedidoId)
            .OnDelete(DeleteBehavior.Cascade);

        // O webhook localiza o pagamento por provedor + id externo.
        builder.HasIndex(p => new { p.Provedor, p.IdExterno }).IsUnique();
    }
}

public class RastreioEntregaConfiguration : IEntityTypeConfiguration<RastreioEntrega>
{
    public void Configure(EntityTypeBuilder<RastreioEntrega> builder)
    {
        builder.ToTable("RastreiosEntrega");

        builder.HasOne(r => r.Pedido)
            .WithMany(p => p.Rastreios)
            .HasForeignKey(r => r.PedidoId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(r => new { r.PedidoId, r.RegistradoEm }).IsDescending(false, true);
    }
}

public class PedidoHistoricoStatusConfiguration : IEntityTypeConfiguration<PedidoHistoricoStatus>
{
    public void Configure(EntityTypeBuilder<PedidoHistoricoStatus> builder)
    {
        builder.ToTable("PedidosHistoricoStatus");

        builder.HasOne<Pedido>()
            .WithMany(p => p.Historico)
            .HasForeignKey(h => h.PedidoId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public class EntregadorConfiguration : IEntityTypeConfiguration<Entregador>
{
    public void Configure(EntityTypeBuilder<Entregador> builder)
    {
        builder.ToTable("Entregadores");
        builder.HasKey(e => new { e.EstabelecimentoId, e.UsuarioId });

        builder.HasOne(e => e.Estabelecimento)
            .WithMany(e => e.Entregadores)
            .HasForeignKey(e => e.EstabelecimentoId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(e => e.Usuario)
            .WithMany()
            .HasForeignKey(e => e.UsuarioId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

public class TokenRenovacaoConfiguration : IEntityTypeConfiguration<TokenRenovacao>
{
    public void Configure(EntityTypeBuilder<TokenRenovacao> builder)
    {
        builder.ToTable("TokensRenovacao");
        builder.Property(t => t.TokenHash).HasMaxLength(64).IsFixedLength();

        builder.HasOne(t => t.Usuario)
            .WithMany(u => u.TokensRenovacao)
            .HasForeignKey(t => t.UsuarioId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(t => t.TokenHash).IsUnique();
    }
}
