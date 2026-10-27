using Azure.Communication.Email;
using Azure.Storage.Blobs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xepa.Application;
using Xepa.Application.Administracao;
using Xepa.Application.Contas;
using Xepa.Application.Indicadores;
using Xepa.Application.Notificacoes;
using Xepa.Application.Ofertas;
using Xepa.Application.Pagamentos;
using Xepa.Application.Pedidos;
using Xepa.Application.Suporte;
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
        services.AddScoped<RecuperacaoSenhaService>();
        services.AddScoped<PedidoService>();
        services.AddScoped<PedidoLojaService>();
        services.AddScoped<EntregaService>();
        services.AddScoped<EnderecoService>();
        services.AddScoped<PagamentoService>();
        services.AddScoped<DenunciaService>();
        services.AddScoped<FavoritoService>();
        services.AddScoped<IndicadoresService>();
        services.AddScoped<AdminService>();
        services.AddScoped<AdminEntregadoresService>();
        services.AddScoped<AdminPedidosService>();
        services.AddScoped<AdminCadastrosService>();
        services.AddScoped<LojaPainelService>();
        services.AddScoped<CadastroLojaService>();
        services.AddScoped<NotificacaoService>();
        services.AddScoped<SuporteService>();
        services.AddScoped<ExclusaoContaService>();

        services.AddSingleton<IHasherSenha, HasherSenha>();
        services.AddScoped<IReservaPedidos, ReservaPedidosSql>();
        services.AddScoped<IConfirmacaoPagamento, ConfirmacaoPagamentoSql>();
        services.AddScoped<PushService>();
        services.TryAddSingleton<INotificadorPedidos, NotificadorNulo>(); // a API troca pelo SignalR
        // Todo aviso de pedido também vai por push para o celular do cliente (venha da API ou do portal).
        var notificador = services.Last(d => d.ServiceType == typeof(INotificadorPedidos));
        services.Remove(notificador);
        services.AddSingleton<INotificadorPedidos>(sp => new NotificadorComPush(
            notificador.ImplementationInstance as INotificadorPedidos
            ?? (INotificadorPedidos)ActivatorUtilities.CreateInstance(sp, notificador.ImplementationType!),
            sp.GetRequiredService<IServiceScopeFactory>()));

        // Firebase Cloud Messaging com a conta de serviço; sem ela, o push só vai para o log.
        var firebase = config["Firebase:ContaServico"];
        if (!string.IsNullOrWhiteSpace(firebase))
            services.AddHttpClient<IEnvioPush, EnvioPushFcm>((http, sp) =>
                new EnvioPushFcm(http, firebase, sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<EnvioPushFcm>>()));
        else
            services.AddSingleton<IEnvioPush, EnvioPushLog>();

        // Mercado Pago com credenciais; sem elas, gateway simulado (só fora de produção).
        var mp = config.GetSection(OpcoesMercadoPago.Secao).Get<OpcoesMercadoPago>() ?? new OpcoesMercadoPago();
        services.AddSingleton(mp);
        if (mp.Configurado)
        {
            if (mp.PixSimulado)
            {
                if (env.IsProduction())
                    throw new InvalidOperationException("MercadoPago:PixSimulado não pode ser usado em produção.");
                services.AddSingleton<GatewaySimulado>();
            }
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

        var email = config["Email:ConnectionString"];
        if (!string.IsNullOrWhiteSpace(email))
            services.AddSingleton<IEnvioEmail>(new EnvioEmailAzure(new EmailClient(email), config["Email:Remetente"]!));
        else
            services.AddSingleton<IEnvioEmail, EnvioEmailLog>();

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
