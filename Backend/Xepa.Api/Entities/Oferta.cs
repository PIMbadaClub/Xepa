namespace Xepa.Api.Entities;

public class Oferta : Entidade
{
    public int EstabelecimentoId { get; set; }
    public Estabelecimento Estabelecimento { get; set; } = null!;

    public required string Titulo { get; set; }
    public string? Descricao { get; set; }
    public string? FotoUrl { get; set; }
    public decimal PrecoOriginal { get; set; }
    public decimal Preco { get; set; }
    public int QuantidadeDisponivel { get; set; }

    /// <summary>Quanto de comida cada unidade salva do lixo (o "kg salvos" do app).</summary>
    public decimal? PesoEstimadoKg { get; set; }

    public DateTimeOffset RetiradaInicio { get; set; }

    /// <summary>Horário limite de retirada/entrega (RF07); depois dele a oferta sai da listagem.</summary>
    public DateTimeOffset RetiradaFim { get; set; }

    /// <summary>Remoção lógica (RF06): oferta com pedido não pode ser apagada de verdade.</summary>
    public bool Ativa { get; set; } = true;

    public List<Pedido> Pedidos { get; set; } = [];
}
