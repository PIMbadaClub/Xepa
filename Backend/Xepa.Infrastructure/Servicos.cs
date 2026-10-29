using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Xepa.Application;
using Xepa.Domain;
using Xepa.Domain.Entities;
using Xepa.Infrastructure.Data;

namespace Xepa.Infrastructure;

public class HasherSenha : IHasherSenha
{
    private readonly PasswordHasher<Usuario> hasher = new();

    public string Gerar(Usuario usuario, string senha) => hasher.HashPassword(usuario, senha);

    public bool Conferir(Usuario usuario, string senha) =>
        hasher.VerifyHashedPassword(usuario, usuario.SenhaHash, senha) != PasswordVerificationResult.Failed;
}

/// <summary>Chama sp_CriarPedido: valida a oferta, reserva o estoque e grava o pedido na mesma transação.</summary>
public class ReservaPedidosSql(XepaDbContext db) : IReservaPedidos
{
    public async Task<int> CriarAsync(int clienteId, int ofertaId, int quantidade, TipoEntrega tipoEntrega,
        decimal taxaEntrega, int? enderecoId, CancellationToken ct)
    {
        var pedidoId = new SqlParameter("@PedidoId", SqlDbType.Int) { Direction = ParameterDirection.Output };
        try
        {
            await db.Database.ExecuteSqlRawAsync(
                "EXEC dbo.sp_CriarPedido @ClienteId, @OfertaId, @Quantidade, @TipoEntrega, @TaxaEntrega, @EnderecoId, @PedidoId OUTPUT",
                [
                    new SqlParameter("@ClienteId", clienteId),
                    new SqlParameter("@OfertaId", ofertaId),
                    new SqlParameter("@Quantidade", quantidade),
                    new SqlParameter("@TipoEntrega", tipoEntrega.ToString()),
                    new SqlParameter("@TaxaEntrega", SqlDbType.Decimal) { Precision = 10, Scale = 2, Value = taxaEntrega },
                    new SqlParameter("@EnderecoId", (object?)enderecoId ?? DBNull.Value),
                    pedidoId
                ], ct);
        }
        catch (SqlException e) when (e.Number is >= 50001 and <= 50099)
        {
            // Erros de regra lançados pela procedure com THROW 5000x.
            throw new RegraDeNegocioException(e.Message);
        }

        return (int)pedidoId.Value;
    }
}

/// <summary>
/// Estimativa por distância em linha reta (Haversine) com fator de 1,3 para aproximar o trajeto pelas ruas.
/// Usada quando a chave do Azure Maps não está configurada.
/// </summary>
public class MapasEstimados : IServicoMapas
{
    private const double FatorRuas = 1.3;
    private const double VelocidadeMediaKmH = 25;

    public Task<Rota> CalcularRotaAsync(Coordenada origem, Coordenada destino, CancellationToken ct)
    {
        var km = Geo.DistanciaKm(origem, destino) * FatorRuas;
        return Task.FromResult(new Rota(Math.Round(km, 2), (int)Math.Ceiling(km / VelocidadeMediaKmH * 60), [origem, destino]));
    }

    /// <summary>Sem Azure Maps não há geocodificação: o app envia as coordenadas do GPS.</summary>
    public Task<Coordenada?> GeocodificarAsync(Endereco endereco, CancellationToken ct) => Task.FromResult<Coordenada?>(null);
}

/// <summary>
/// A cada minuto cancela pedidos sem pagamento há mais de 15 minutos (RN03, sp_ExpirarPedidosNaoPagos).
/// Só roda enquanto a API recebe requisições: o banco serverless da Azure pausa quando fica ocioso,
/// e consultar a cada minuto o manteria ligado o tempo todo, esgotando a cota grátis do mês.
/// </summary>
public class ExpiradorPedidos(IServiceScopeFactory scopes, ILogger<ExpiradorPedidos> log) : BackgroundService
{
    /// <summary>Além dos 15 minutos do RN03, para expirar o último pedido criado antes de parar.</summary>
    static readonly TimeSpan JanelaAtividade = TimeSpan.FromMinutes(30);
    static long ultimaAtividade = DateTime.UtcNow.Ticks;

    /// <summary>Chamado pelo pipeline da API a cada requisição de usuário (não pelo health check).</summary>
    public static void RegistrarAtividade() => Interlocked.Exchange(ref ultimaAtividade, DateTime.UtcNow.Ticks);

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        while (await timer.WaitForNextTickAsync(ct))
        {
            if (DateTime.UtcNow - new DateTime(Interlocked.Read(ref ultimaAtividade)) > JanelaAtividade)
                continue;
            try
            {
                using var scope = scopes.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<XepaDbContext>();
                await db.Database.ExecuteSqlRawAsync("EXEC dbo.sp_ExpirarPedidosNaoPagos @Minutos = 15", ct);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "Falha ao expirar pedidos não pagos.");
            }
        }
    }
}
