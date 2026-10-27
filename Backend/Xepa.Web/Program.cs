using Microsoft.AspNetCore.Authentication.Cookies;
using Xepa.Infrastructure;
using Xepa.Infrastructure.Seguranca;
using Xepa.Web;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddXepa(builder.Configuration, builder.Environment);

// Pedidos passam pela API, que muda o status e avisa app e entregador em tempo real.
var jwt = builder.Configuration.GetSection(OpcoesJwt.Secao).Get<OpcoesJwt>() ?? new OpcoesJwt();
builder.Services.AddSingleton(jwt);
builder.Services.AddSingleton<GeradorTokenJwt>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddHttpClient<ApiXepa>(c =>
    c.BaseAddress = new Uri(builder.Configuration["Api:UrlBase"] ?? throw new InvalidOperationException("Configure Api:UrlBase.")));

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(o =>
    {
        o.LoginPath = "/conta/entrar";
        o.LogoutPath = "/conta/sair";
        o.AccessDeniedPath = "/conta/acesso-negado";
        o.ExpireTimeSpan = TimeSpan.FromHours(8);
        o.SlidingExpiration = true;
        o.Cookie.Name = "xepa.portal";
        o.Cookie.HttpOnly = true;
        o.Cookie.SameSite = SameSiteMode.Lax;
        o.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
    });
builder.Services.AddAuthorization();

// Todo POST do portal exige o token antifalsificação (CSRF); token vencido volta para a tela com aviso, sem erro 400.
builder.Services.AddControllersWithViews(o =>
{
    o.Filters.Add(new Microsoft.AspNetCore.Mvc.AutoValidateAntiforgeryTokenAttribute());
    o.Filters.Add<TokenExpirado>();
});
builder.Services.AddHealthChecks();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/erro");
    app.UseHsts();
    app.UseHttpsRedirection();
}

// Datas e valores sempre em pt-BR, independentemente da cultura do servidor (o container no Azure é invariante).
app.UseRequestLocalization(o => o.SetDefaultCulture("pt-BR").AddSupportedCultures("pt-BR").AddSupportedUICultures("pt-BR"));
// Páginas não ficam no cache do navegador: o "Voltar" busca de novo, com token e sessão atuais.
app.Use(async (contexto, proximo) =>
{
    contexto.Response.OnStarting(() =>
    {
        if (contexto.Response.ContentType?.StartsWith("text/html") == true)
            contexto.Response.Headers.CacheControl = "no-store";
        return Task.CompletedTask;
    });
    await proximo();
});
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();
app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
