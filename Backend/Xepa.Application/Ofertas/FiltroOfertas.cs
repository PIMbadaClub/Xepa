using System.ComponentModel.DataAnnotations;
using Xepa.Domain.Entities;

namespace Xepa.Application.Ofertas;

/// <summary>Parâmetros de GET /api/ofertas (vêm da query string).</summary>
public class FiltroOfertas : IValidatableObject
{
    /// <summary>Procura no título da oferta e no nome do estabelecimento.</summary>
    [MaxLength(100)]
    public string? Busca { get; init; }

    public CategoriaEstabelecimento? Categoria { get; init; }

    /// <summary>Só lojas desta cidade (o app manda a cidade do endereço principal do cliente).</summary>
    [MaxLength(80)]
    public string? Cidade { get; init; }

    /// <summary>Só as ofertas de uma loja (tela de favoritos do app).</summary>
    public int? EstabelecimentoId { get; init; }

    [Range(-90, 90)]
    public double? Latitude { get; init; }

    [Range(-180, 180)]
    public double? Longitude { get; init; }

    /// <summary>Só traz ofertas até essa distância; exige latitude e longitude.</summary>
    [Range(0.1, 100)]
    public double? RaioKm { get; init; }

    [Range(1, int.MaxValue)]
    public int Pagina { get; init; } = 1;

    [Range(1, 50)]
    public int TamanhoPagina { get; init; } = 20;

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Latitude.HasValue != Longitude.HasValue)
            yield return new ValidationResult("Informe latitude e longitude juntas.", [nameof(Latitude), nameof(Longitude)]);

        if (RaioKm.HasValue && !Latitude.HasValue)
            yield return new ValidationResult("O raio só pode ser usado com latitude e longitude.", [nameof(RaioKm)]);
    }
}
