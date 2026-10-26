using Xepa.Domain.Entities;

namespace Xepa.Application.Ofertas;

public class OfertaDto
{
    public int Id { get; init; }
    public TipoOferta Tipo { get; init; }
    public required string Titulo { get; init; }
    public string? Descricao { get; init; }
    public string? FotoUrl { get; init; }
    public decimal PrecoOriginal { get; init; }
    public decimal Preco { get; init; }
    public int DescontoPercentual => PrecoOriginal == 0 ? 0 : (int)Math.Round((1 - Preco / PrecoOriginal) * 100);
    public int Restantes { get; init; }
    public decimal? KgSalvos { get; init; }
    public DateTimeOffset RetiradaInicio { get; init; }
    public DateTimeOffset RetiradaFim { get; init; }

    /// <summary>Só vem preenchida quando a requisição informa latitude e longitude.</summary>
    public double? DistanciaKm { get; init; }

    public required EstabelecimentoResumoDto Estabelecimento { get; init; }
}

public class EstabelecimentoResumoDto
{
    public int Id { get; init; }
    public required string Nome { get; init; }
    public CategoriaEstabelecimento Categoria { get; init; }
    public string? LogoUrl { get; init; }
    public required string Bairro { get; init; }
    public double? Latitude { get; init; }
    public double? Longitude { get; init; }
}
