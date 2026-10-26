using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Xepa.Application;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Integracoes;

public class OpcoesMapas
{
    public const string Secao = "Mapas";

    /// <summary>Chave de assinatura do Azure Maps. Vazio = estimativa por Haversine e mapa do OpenStreetMap.</summary>
    public string? AzureMapsChave { get; init; }

    public bool AzureConfigurado => !string.IsNullOrWhiteSpace(AzureMapsChave);
}

/// <summary>Rotas (Route Directions) e geocodificação (Search Address) do Azure Maps.</summary>
public class AzureMaps(HttpClient http, OpcoesMapas opcoes, MapasEstimados reserva, ILogger<AzureMaps> log) : IServicoMapas
{
    public async Task<Rota> CalcularRotaAsync(Coordenada origem, Coordenada destino, CancellationToken ct)
    {
        var consulta = string.Create(CultureInfo.InvariantCulture,
            $"{origem.Latitude},{origem.Longitude}:{destino.Latitude},{destino.Longitude}");
        try
        {
            var resp = await http.GetFromJsonAsync<RespostaRota>(
                $"route/directions/json?api-version=1.0&travelMode=car&query={consulta}&subscription-key={opcoes.AzureMapsChave}", ct);
            var resumo = resp?.Routes?.FirstOrDefault()?.Summary;
            if (resumo is not null)
                return new Rota(Math.Round(resumo.LengthInMeters / 1000.0, 2), (int)Math.Ceiling(resumo.TravelTimeInSeconds / 60.0));
        }
        catch (HttpRequestException e)
        {
            // Se o serviço de rotas falhar, a estimativa evita travar a compra.
            log.LogWarning(e, "Azure Maps indisponível; usando a estimativa de rota.");
        }
        return await reserva.CalcularRotaAsync(origem, destino, ct);
    }

    public async Task<Coordenada?> GeocodificarAsync(Endereco e, CancellationToken ct)
    {
        var texto = Uri.EscapeDataString($"{e.Logradouro}, {e.Numero}, {e.Bairro}, {e.Cidade} - {e.Uf}, {e.Cep}");
        try
        {
            var resp = await http.GetFromJsonAsync<RespostaBusca>(
                $"search/address/json?api-version=1.0&countrySet=BR&limit=1&language=pt-BR&query={texto}&subscription-key={opcoes.AzureMapsChave}", ct);
            var posicao = resp?.Results?.FirstOrDefault()?.Position;
            return posicao is null ? null : new Coordenada(posicao.Lat, posicao.Lon);
        }
        catch (HttpRequestException ex)
        {
            log.LogWarning(ex, "Falha ao geocodificar o endereço no Azure Maps.");
            return null;
        }
    }

    private record RespostaRota(List<RotaAzure>? Routes);
    private record RotaAzure(ResumoRota? Summary);
    private record ResumoRota(int LengthInMeters, int TravelTimeInSeconds);
    private record RespostaBusca(List<ResultadoBusca>? Results);
    private record ResultadoBusca(Posicao? Position);
    private record Posicao([property: JsonPropertyName("lat")] double Lat, [property: JsonPropertyName("lon")] double Lon);
}
