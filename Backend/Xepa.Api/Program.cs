using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Xepa.Api.Seguranca;
using Xepa.Api.TempoReal;
using Xepa.Application.Pagamentos;
using Xepa.Infrastructure.Seguranca;
using Xepa.Application;
using Xepa.Application.Contas;
using Xepa.Infrastructure;
using Xepa.Infrastructure.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<INotificadorPedidos, NotificadorSignalR>();
builder.Services.AddXepa(builder.Configuration, builder.Environment);
builder.Services.AddSignalR();
builder.Services.AddHostedService<ExpiradorPedidos>();

var jwt = builder.Configuration.GetSection(OpcoesJwt.Secao).Get<OpcoesJwt>() ?? new OpcoesJwt();
if (jwt.Chave.Length < 32)
    throw new InvalidOperationException("Configure Jwt:Chave com pelo menos 32 caracteres.");
builder.Services.AddSingleton(jwt);
builder.Services.AddSingleton<IGeradorToken, GeradorTokenJwt>();
builder.Services.AddScoped<ContaService>(); // sessões do app; o portal usa cookie e só o CredenciaisService

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = jwt.Emissor,
            ValidAudience = jwt.Publico,
            IssuerSigningKey = jwt.ChaveAssinatura(),
            RoleClaimType = System.Security.Claims.ClaimTypes.Role,
            NameClaimType = "name",
            ClockSkew = TimeSpan.FromSeconds(30)
        };
        // WebSocket não envia cabeçalho Authorization: o SignalR manda o token na query string.
        o.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                if (ctx.HttpContext.Request.Path.StartsWithSegments(PedidosHub.Rota)
                    && ctx.Request.Query["access_token"] is { Count: > 0 } token)
                    ctx.Token = token;
                return Task.CompletedTask;
            }
        };
    });

// Portal e app web (Flutter web) chamam a API de outra origem.
var origens = builder.Configuration.GetSection("Cors:Origens").Get<string[]>() ?? [];
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.WithOrigins(origens).AllowAnyHeader().AllowAnyMethod().AllowCredentials()));
builder.Services.AddAuthorization();

// Até 10 tentativas por minuto por IP nas rotas de login e cadastro.
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy(Program.LimiteLogin, http => RateLimitPartition.GetFixedWindowLimiter(
        http.Connection.RemoteIpAddress?.ToString() ?? "anonimo",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) }));
});

builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<TratadorErros>();
builder.Services.AddHealthChecks().AddDbContextCheck<XepaDbContext>("banco");

builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddOpenApi();

var app = builder.Build();

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwaggerUI(o => o.SwaggerEndpoint("/openapi/v1.json", "Xepa API"));
}
else
{
    // Em desenvolvimento fica sem redirecionar, para o emulador Android acessar http://10.0.2.2:5000.
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseStaticFiles();
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<PedidosHub>(PedidosHub.Rota);
app.MapHealthChecks("/health");

app.Run();

public partial class Program
{
    public const string LimiteLogin = "login";
}
