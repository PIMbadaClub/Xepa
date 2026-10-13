using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Xepa.Api.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<XepaDbContext>(options =>
{
    options.UseSqlServer(builder.Configuration.GetConnectionString("Xepa"));

    // Dados de demonstração só em desenvolvimento; entram no "dotnet ef database update".
    if (builder.Environment.IsDevelopment())
        options.UseSeeding(DadosIniciais.Popular).UseAsyncSeeding(DadosIniciais.PopularAsync);
});

builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwaggerUI(o => o.SwaggerEndpoint("/openapi/v1.json", "Xepa API"));
}
else
{
    // Em desenvolvimento fica sem redirecionar, para o emulador Android acessar http://10.0.2.2:5000.
    app.UseHttpsRedirection();
}

app.UseAuthorization();

app.MapControllers();

app.Run();
