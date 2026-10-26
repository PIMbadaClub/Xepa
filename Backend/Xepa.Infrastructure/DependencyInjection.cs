using Azure.Storage.Blobs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xepa.Application;
using Xepa.Application.Contas;
using Xepa.Application.Ofertas;
using Xepa.Application.Pedidos;
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
        services.AddScoped<EnderecoService>();

        services.AddSingleton<IHasherSenha, HasherSenha>();
        services.AddScoped<IReservaPedidos, ReservaPedidosSql>();
        services.AddSingleton<IServicoMapas, MapasEstimados>();

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
