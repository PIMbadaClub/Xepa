using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Xepa.Domain.Entities;

namespace Xepa.Application;

/// <summary>Acesso aos dados usado pelos serviços. Implementado pelo XepaDbContext na infraestrutura.</summary>
public interface IXepaDb
{
    DbSet<Usuario> Usuarios { get; }
    DbSet<Estabelecimento> Estabelecimentos { get; }
    DbSet<EnderecoUsuario> Enderecos { get; }
    DbSet<Oferta> Ofertas { get; }
    DbSet<Pedido> Pedidos { get; }
    DbSet<Pagamento> Pagamentos { get; }
    DbSet<Favorito> Favoritos { get; }
    DbSet<TokenRenovacao> TokensRenovacao { get; }
    DbSet<Denuncia> Denuncias { get; }
    DbSet<Repasse> Repasses { get; }

    Task<int> SaveChangesAsync(CancellationToken ct = default);

    /// <summary>Usado para recarregar entidades alteradas por procedures.</summary>
    EntityEntry<TEntity> Entry<TEntity>(TEntity entity) where TEntity : class;
}

/// <summary>Criação do pedido com reserva de estoque atômica (procedure sp_CriarPedido).</summary>
public interface IReservaPedidos
{
    Task<int> CriarAsync(int clienteId, int ofertaId, int quantidade, TipoEntrega tipoEntrega, decimal taxaEntrega,
        int? enderecoId, CancellationToken ct);
}

public interface IHasherSenha
{
    string Gerar(Usuario usuario, string senha);
    bool Conferir(Usuario usuario, string senha);
}

/// <summary>Emite o token de acesso (JWT) do app. Implementado na API.</summary>
public interface IGeradorToken
{
    TimeSpan ValidadeAcesso { get; }
    string GerarAcesso(Usuario usuario, int? estabelecimentoId);
}

public record Coordenada(double Latitude, double Longitude);

/// <summary>Rota pelas ruas. <paramref name="Pontos"/> é o traçado para desenhar no mapa (só a reta, na estimativa).</summary>
public record Rota(double DistanciaKm, int MinutosEstimados, IReadOnlyList<Coordenada> Pontos);

/// <summary>Geocodificação e rotas. A implementação de produção usa o Azure Maps.</summary>
public interface IServicoMapas
{
    Task<Rota> CalcularRotaAsync(Coordenada origem, Coordenada destino, CancellationToken ct);

    /// <summary>Converte o endereço em coordenadas; null quando não encontra (ou sem Azure Maps).</summary>
    Task<Coordenada?> GeocodificarAsync(Endereco endereco, CancellationToken ct);
}

public static class Geo
{
    private const double RaioTerraKm = 6371;

    /// <summary>Distância em linha reta pela fórmula de Haversine.</summary>
    public static double DistanciaKm(Coordenada a, Coordenada b)
    {
        static double Rad(double g) => g * Math.PI / 180;
        var dLat = Rad(b.Latitude - a.Latitude);
        var dLng = Rad(b.Longitude - a.Longitude);
        var h = Math.Pow(Math.Sin(dLat / 2), 2)
                + Math.Cos(Rad(a.Latitude)) * Math.Cos(Rad(b.Latitude)) * Math.Pow(Math.Sin(dLng / 2), 2);
        return 2 * RaioTerraKm * Math.Asin(Math.Sqrt(h));
    }
}

/// <summary>Fotos de ofertas e logotipos: Blob Storage em produção, disco local em desenvolvimento.</summary>
public interface IArmazenamento
{
    Task<string> SalvarAsync(Stream conteudo, string extensao, string contentType, CancellationToken ct);
}

public class NaoEncontradoException(string mensagem) : Exception(mensagem);

public class AcessoNegadoException(string mensagem) : Exception(mensagem);
