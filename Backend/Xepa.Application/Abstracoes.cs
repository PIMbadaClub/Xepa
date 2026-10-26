using Microsoft.EntityFrameworkCore;
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

    Task<int> SaveChangesAsync(CancellationToken ct = default);
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

public record Rota(double DistanciaKm, int MinutosEstimados);

/// <summary>Geocodificação e rotas. A implementação de produção usa o Azure Maps.</summary>
public interface IServicoMapas
{
    Task<Rota> CalcularRotaAsync(Coordenada origem, Coordenada destino, CancellationToken ct);
}

/// <summary>Fotos de ofertas e logotipos: Blob Storage em produção, disco local em desenvolvimento.</summary>
public interface IArmazenamento
{
    Task<string> SalvarAsync(Stream conteudo, string extensao, string contentType, CancellationToken ct);
}

public class NaoEncontradoException(string mensagem) : Exception(mensagem);

public class AcessoNegadoException(string mensagem) : Exception(mensagem);
