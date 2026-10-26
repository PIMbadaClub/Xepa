namespace Xepa.Domain.Entities;

public class Oferta : Entidade
{
    public int EstabelecimentoId { get; set; }
    public Estabelecimento Estabelecimento { get; set; } = null!;

    public TipoOferta Tipo { get; set; } = TipoOferta.Prato;
    public required string Titulo { get; set; }
    public string? Descricao { get; set; }
    public string? FotoUrl { get; set; }
    public decimal PrecoOriginal { get; set; }
    public decimal Preco { get; set; }
    public int QuantidadeDisponivel { get; set; }

    /// <summary>Quanto de comida cada unidade salva do lixo (o "kg salvos" do app).</summary>
    public decimal? PesoEstimadoKg { get; set; }

    public DateTimeOffset RetiradaInicio { get; set; }

    /// <summary>Horário limite de retirada/entrega; depois dele a oferta sai da listagem (RN01).</summary>
    public DateTimeOffset RetiradaFim { get; set; }

    /// <summary>Remoção lógica: oferta com pedido não pode ser apagada de verdade (RN06).</summary>
    public bool Ativa { get; set; } = true;

    public List<Pedido> Pedidos { get; set; } = [];

    public bool EstaDisponivel(DateTimeOffset agora) =>
        Ativa && QuantidadeDisponivel > 0 && RetiradaFim > agora;

    public void Reservar(int quantidade)
    {
        if (quantidade <= 0)
            throw new RegraDeNegocioException("Quantidade inválida.");
        if (!EstaDisponivel(DateTimeOffset.UtcNow))
            throw new RegraDeNegocioException("Oferta indisponível.");
        if (quantidade > QuantidadeDisponivel)
            throw new RegraDeNegocioException("Quantidade maior que a disponível.");

        QuantidadeDisponivel -= quantidade;
    }

    public void Devolver(int quantidade)
    {
        if (quantidade <= 0)
            throw new RegraDeNegocioException("Quantidade inválida.");

        QuantidadeDisponivel += quantidade;
    }

    /// <summary>Confere os dados informados pela loja antes de salvar (RN02 e janela de retirada válida).</summary>
    public void Validar()
    {
        if (Preco <= 0 || Preco >= PrecoOriginal)
            throw new RegraDeNegocioException("O preço com desconto deve ser maior que zero e menor que o preço original.");
        if (QuantidadeDisponivel < 0)
            throw new RegraDeNegocioException("A quantidade não pode ser negativa.");
        if (RetiradaFim <= RetiradaInicio)
            throw new RegraDeNegocioException("O fim da retirada deve ser depois do início.");
    }
}
