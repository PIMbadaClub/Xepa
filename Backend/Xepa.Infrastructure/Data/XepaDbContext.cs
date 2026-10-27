using Microsoft.EntityFrameworkCore;
using Xepa.Application;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data;

public class XepaDbContext(DbContextOptions<XepaDbContext> options) : DbContext(options), IXepaDb
{
    public DbSet<Usuario> Usuarios => Set<Usuario>();
    public DbSet<Estabelecimento> Estabelecimentos => Set<Estabelecimento>();
    public DbSet<EnderecoUsuario> Enderecos => Set<EnderecoUsuario>();
    public DbSet<Oferta> Ofertas => Set<Oferta>();
    public DbSet<Pedido> Pedidos => Set<Pedido>();
    public DbSet<Favorito> Favoritos => Set<Favorito>();
    public DbSet<Pagamento> Pagamentos => Set<Pagamento>();
    public DbSet<RastreioEntrega> RastreiosEntrega => Set<RastreioEntrega>();
    public DbSet<PedidoHistoricoStatus> PedidosHistoricoStatus => Set<PedidoHistoricoStatus>();
    public DbSet<Entregador> Entregadores => Set<Entregador>();
    public DbSet<TokenRenovacao> TokensRenovacao => Set<TokenRenovacao>();
    public DbSet<CodigoRecuperacaoSenha> CodigosRecuperacao => Set<CodigoRecuperacaoSenha>();
    public DbSet<Denuncia> Denuncias => Set<Denuncia>();
    public DbSet<Repasse> Repasses => Set<Repasse>();
    public DbSet<RepasseEntregador> RepassesEntregadores => Set<RepasseEntregador>();
    public DbSet<ConversaSuporte> ConversasSuporte => Set<ConversaSuporte>();
    public DbSet<MensagemSuporte> MensagensSuporte => Set<MensagemSuporte>();
    public DbSet<DispositivoPush> DispositivosPush => Set<DispositivoPush>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Busca sem diferenciar maiúsculas nem acentos: "pao" encontra "Pão".
        modelBuilder.UseCollation("Latin1_General_100_CI_AI");

        // Cada entidade tem sua classe em Data/Configurations.
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(XepaDbContext).Assembly);
    }

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        configurationBuilder.Properties<decimal>().HavePrecision(10, 2);

        // Enums gravados como texto, para o banco ser legível sem consultar o código.
        configurationBuilder.Properties<TipoUsuario>().HaveConversion<string>().HaveMaxLength(20);
        configurationBuilder.Properties<CategoriaEstabelecimento>().HaveConversion<string>().HaveMaxLength(20);
        configurationBuilder.Properties<TipoEntrega>().HaveConversion<string>().HaveMaxLength(20);
        configurationBuilder.Properties<StatusPedido>().HaveConversion<string>().HaveMaxLength(20);
        configurationBuilder.Properties<TipoOferta>().HaveConversion<string>().HaveMaxLength(20);
        configurationBuilder.Properties<StatusCadastro>().HaveConversion<string>().HaveMaxLength(20);
        configurationBuilder.Properties<MetodoPagamento>().HaveConversion<string>().HaveMaxLength(20);
        configurationBuilder.Properties<StatusPagamento>().HaveConversion<string>().HaveMaxLength(20);
        configurationBuilder.Properties<MotivoDenuncia>().HaveConversion<string>().HaveMaxLength(30);
        configurationBuilder.Properties<StatusDenuncia>().HaveConversion<string>().HaveMaxLength(20);
        configurationBuilder.Properties<StatusConversa>().HaveConversion<string>().HaveMaxLength(20);
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        PreencherDatas();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        PreencherDatas();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    private void PreencherDatas()
    {
        var agora = DateTimeOffset.UtcNow;
        foreach (var entrada in ChangeTracker.Entries<Entidade>())
        {
            if (entrada.State == EntityState.Added)
                entrada.Entity.CriadoEm = agora;
            else if (entrada.State == EntityState.Modified)
                entrada.Entity.AtualizadoEm = agora;
        }
    }
}
