using Azure.Storage.Blobs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xepa.Application;
using Xepa.Application.Contas;
using Xepa.Application.Ofertas;
using Xepa.Application.Pagamentos;
using Xepa.Application.Pedidos;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xepa.Infrastructure.Integracoes;
using Xepa.Infrastructure.Data;

namespace Xepa.Infrastructure;

public static class DependencyInjection
{
    /// <summary>
    /// Registra banco, serviços de aplicação e integrações. Usado pela API e pelo portal, que compartilham as regras.
    /// </summary>
    public static IServiceCollection AddXepa(this IServiceCollection services, IConfiguration config, IHostEnvironment env)
    {
        services.AddDbContext<XepaDbContext>(options =>
        {
            options.UseSqlServer(config.GetConnectionString("Xepa"),
                sql => sql.EnableRetryOnFailure()); // Azure SQL serverless pausa quando ocioso

            // Dados de demonstração só em desenvolvimento; entram no "dotnet ef database update".
            if (env.IsDevelopment())
                options.UseSeeding(DadosIniciais.Popular).UseAsyncSeeding(DadosIniciais.PopularAsync);
        });
        services.AddScoped<IXepaDb>(sp => sp.GetRequiredService<XepaDbContext>());

        services.AddScoped<OfertaConsultaService>();
        services.AddScoped<OfertaGestaoService>();
        services.AddScoped<CredenciaisService>();
        services.AddScoped<PedidoService>();
        services.AddScoped<PedidoLojaService>();
        services.AddScoped<EntregaService>();
        services.AddScoped<EnderecoService>();
        services.AddScoped<PagamentoService>();

        services.AddSingleton<IHasherSenha, HasherSenha>();
        services.AddScoped<IReservaPedidos, ReservaPedidosSql>();
        services.AddScoped<IConfirmacaoPagamento, ConfirmacaoPagamentoSql>();
        services.TryAddSingleton<INotificadorPedidos, NotificadorNulo>(); // a API troca pelo SignalR

        // Mercado Pago com credenciais; sem elas, gateway simulado (só fora de produção).
        var mp = config.GetSection(OpcoesMercadoPago.Secao).Get<OpcoesMercadoPago>() ?? new OpcoesMercadoPago();
        services.AddSingleton(mp);
        if (mp.Configurado)
        {
            services.AddHttpClient<IGatewayPagamento, GatewayMercadoPago>(c => c.BaseAddress = new Uri("https://api.mercadopago.com/"));
        }
        else
        {
            if (env.IsProduction())
                throw new InvalidOperationException("Configure MercadoPago:AccessToken em produção.");
            services.AddSingleton<GatewaySimulado>();
            services.AddSingleton<IGatewayPagamento>(sp => sp.GetRequiredService<GatewaySimulado>());
        }

        // Azure Maps com chave; sem ela, estimativa de rota por Haversine.
        var mapas = config.GetSection(OpcoesMapas.Secao).Get<OpcoesMapas>() ?? new OpcoesMapas();
        services.AddSingleton(mapas);
        services.AddSingleton<MapasEstimados>();
        if (mapas.AzureConfigurado)
            services.AddHttpClient<IServicoMapas, AzureMaps>(c => c.BaseAddress = new Uri("https://atlas.microsoft.com/"));
        else
            services.AddSingleton<IServicoMapas>(sp => sp.GetRequiredService<MapasEstimados>());

        var blob = config["Armazenamento:BlobConnectionString"];
        if (!string.IsNullOrWhiteSpace(blob))
        {
            var container = new BlobContainerClient(blob, config["Armazenamento:Container"] ?? "fotos");
            services.AddSingleton<IArmazenamento>(new ArmazenamentoBlob(container));
        }
        else
        {
            var pasta = Path.Combine(env.ContentRootPath, "wwwroot", "uploads");
            services.AddSingleton<IArmazenamento>(new ArmazenamentoLocal(pasta, config["Armazenamento:UrlBaseLocal"] ?? "/uploads"));
        }

        return services;
    }
}
