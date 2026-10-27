using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data.Configurations;

public class ConversaSuporteConfiguration : IEntityTypeConfiguration<ConversaSuporte>
{
    public void Configure(EntityTypeBuilder<ConversaSuporte> builder)
    {
        builder.HasOne(c => c.Usuario).WithMany().HasForeignKey(c => c.UsuarioId).OnDelete(DeleteBehavior.Restrict);
        // Uma conversa por conta.
        builder.HasIndex(c => c.UsuarioId).IsUnique();
        // Fila do atendimento: abertas, das mais recentes para as mais antigas.
        builder.HasIndex(c => new { c.Status, c.UltimaMensagemEm });
    }
}

public class MensagemSuporteConfiguration : IEntityTypeConfiguration<MensagemSuporte>
{
    public void Configure(EntityTypeBuilder<MensagemSuporte> builder)
    {
        builder.Property(m => m.Texto).HasMaxLength(2000).IsRequired();

        builder.HasOne(m => m.Conversa).WithMany(c => c.Mensagens).HasForeignKey(m => m.ConversaId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(m => m.Autor).WithMany().HasForeignKey(m => m.AutorId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(m => m.Pedido).WithMany().HasForeignKey(m => m.PedidoId).OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(m => new { m.ConversaId, m.Id });
    }
}
