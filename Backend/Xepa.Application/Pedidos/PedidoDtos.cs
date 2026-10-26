using System.ComponentModel.DataAnnotations;
using Xepa.Domain.Entities;

namespace Xepa.Application.Pedidos;

public class CriarPedidoRequest : IValidatableObject
{
    [Range(1, int.MaxValue)]
    public int OfertaId { get; init; }

    [Range(1, 20)]
    public int Quantidade { get; init; } = 1;

    public TipoEntrega TipoEntrega { get; init; } = TipoEntrega.Retirada;

    /// <summary>Endereço cadastrado do cliente; obrigatório quando TipoEntrega = Entrega.</summary>
    public int? EnderecoId { get; init; }

    [MaxLength(500)]
    public string? Observacao { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (TipoEntrega == TipoEntrega.Entrega && EnderecoId is null)
            yield return new ValidationResult("Informe o endereço de entrega.", [nameof(EnderecoId)]);
    }
}

public class PedidoDto
{
    public int Id { get; init; }
    public StatusPedido Status { get; init; }
    public TipoEntrega TipoEntrega { get; init; }
    public int Quantidade { get; init; }
    public decimal PrecoUnitario { get; init; }
    public decimal TaxaEntrega { get; init; }
    public decimal ValorTotal { get; init; }

    /// <summary>Código que o cliente mostra na loja (RN08); só aparece para o próprio cliente.</summary>
    public string? CodigoRetirada { get; init; }

    public DateTimeOffset CriadoEm { get; init; }

    /// <summary>Primeiro nome do entregador parceiro (pedidos com entrega) e a nota que o cliente deu a ele.</summary>
    public string? NomeEntregador { get; init; }
    public int? NotaEntregador { get; init; }

    public required PedidoOfertaDto Oferta { get; init; }
    public Endereco? EnderecoEntrega { get; init; }
}

public record PedidoOfertaDto(int Id, string Titulo, string? FotoUrl, int EstabelecimentoId, string Estabelecimento,
    DateTimeOffset RetiradaInicio, DateTimeOffset RetiradaFim);

public class AvaliarEntregadorRequest
{
    [Range(1, 5, ErrorMessage = "A nota vai de 1 a 5.")]
    public int Nota { get; init; }

    [MaxLength(300, ErrorMessage = "O comentário pode ter até 300 caracteres.")]
    public string? Comentario { get; init; }
}

public class EnderecoRequest
{
    [Required, MaxLength(40)]
    public required string Apelido { get; init; }

    public bool Principal { get; init; }

    [Required, RegularExpression(@"^\d{8}$", ErrorMessage = "CEP deve ter 8 dígitos.")]
    public required string Cep { get; init; }

    [Required, MaxLength(150)]
    public required string Logradouro { get; init; }

    [Required, MaxLength(20)]
    public required string Numero { get; init; }

    [MaxLength(100)]
    public string? Complemento { get; init; }

    [Required, MaxLength(80)]
    public required string Bairro { get; init; }

    [Required, MaxLength(80)]
    public required string Cidade { get; init; }

    [Required, RegularExpression("^[A-Z]{2}$", ErrorMessage = "UF deve ter 2 letras maiúsculas.")]
    public required string Uf { get; init; }

    /// <summary>Coordenadas do GPS do aparelho; na Sprint 2 o Azure Maps passa a geocodificar pelo CEP.</summary>
    [Range(-90, 90)]
    public double? Latitude { get; init; }

    [Range(-180, 180)]
    public double? Longitude { get; init; }
}

public record EnderecoDto(int Id, string Apelido, bool Principal, Endereco Endereco);

/// <summary>Posições para o mapa do cliente; <c>Rota</c> é o traçado real loja → destino pelas ruas.</summary>
public record RastreioDto(StatusPedido Status, Coordenada? Loja, Coordenada? Destino, Coordenada? Entregador,
    DateTimeOffset? AtualizadoEm, IReadOnlyList<Coordenada>? Rota = null, string? NomeEntregador = null,
    string? PlacaEntregador = null);
