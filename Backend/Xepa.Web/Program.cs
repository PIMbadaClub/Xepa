using Microsoft.AspNetCore.Authentication.Cookies;
using Xepa.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddXepa(builder.Configuration, builder.Environment);

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

// Todo POST do portal exige o token antifalsificação (CSRF).
builder.Services.AddControllersWithViews(o =>
    o.Filters.Add(new Microsoft.AspNetCore.Mvc.AutoValidateAntiforgeryTokenAttribute()));
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
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();
app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
