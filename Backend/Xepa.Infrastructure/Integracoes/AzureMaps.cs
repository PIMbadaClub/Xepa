using System.Collections.Concurrent;
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
    /// <summary>
    /// Rotas já calculadas, por ~11 m de precisão nas pontas. O mapa do cliente e o app do entregador pedem a mesma
    /// rota várias vezes; o cache evita cobrar (e esperar) a chamada de novo.
    /// </summary>
    private static readonly ConcurrentDictionary<string, Rota> Cache = new();

    public async Task<Rota> CalcularRotaAsync(Coordenada origem, Coordenada destino, CancellationToken ct)
    {
        var consulta = string.Create(CultureInfo.InvariantCulture,
            $"{origem.Latitude:0.0000},{origem.Longitude:0.0000}:{destino.Latitude:0.0000},{destino.Longitude:0.0000}");
        if (Cache.TryGetValue(consulta, out var guardada))
            return guardada;
        try
        {
            // Moto: o traçado segue as ruas que o entregador usaria.
            var resp = await http.GetFromJsonAsync<RespostaRota>(
                $"route/directions/json?api-version=1.0&travelMode=motorcycle&routeRepresentation=polyline&query={consulta}&subscription-key={opcoes.AzureMapsChave}", ct);
            var rota = resp?.Routes?.FirstOrDefault();
            if (rota?.Summary is { } resumo)
            {
                var pontos = rota.Legs?.SelectMany(l => l.Points ?? []).Select(p => new Coordenada(p.Latitude, p.Longitude)).ToList();
                var resultado = new Rota(Math.Round(resumo.LengthInMeters / 1000.0, 2), (int)Math.Ceiling(resumo.TravelTimeInSeconds / 60.0),
                    pontos is { Count: > 1 } ? pontos : [origem, destino]);
                if (Cache.Count > 2000)
                    Cache.Clear();
                Cache[consulta] = resultado;
                return resultado;
            }
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
    private record RotaAzure(ResumoRota? Summary, List<TrechoRota>? Legs);
    private record TrechoRota(List<PontoRota>? Points);
    private record PontoRota(double Latitude, double Longitude);
    private record ResumoRota(int LengthInMeters, int TravelTimeInSeconds);
    private record RespostaBusca(List<ResultadoBusca>? Results);
    private record ResultadoBusca(Posicao? Position);
    private record Posicao([property: JsonPropertyName("lat")] double Lat, [property: JsonPropertyName("lon")] double Lon);
}
