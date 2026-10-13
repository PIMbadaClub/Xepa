namespace Xepa.Api.Entities;

/// <summary>
/// Tipo complexo do EF: não tem tabela própria, as colunas ficam na tabela de quem o usa
/// (Estabelecimentos, Enderecos e Pedidos).
/// </summary>
public record Endereco
{
    public required string Cep { get; init; }
    public required string Logradouro { get; init; }
    public required string Numero { get; init; }
    public string? Complemento { get; init; }
    public required string Bairro { get; init; }
    public required string Cidade { get; init; }
    public required string Uf { get; init; }
    public double? Latitude { get; init; }
    public double? Longitude { get; init; }
}
