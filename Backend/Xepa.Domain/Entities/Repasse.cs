namespace Xepa.Domain.Entities;

/// <summary>
/// Valor que a XEPA deve ao estabelecimento pelos pedidos entregues: vendas menos a comissão. As taxas de entrega
/// ficam registradas só para conferência, porque vão para o entregador parceiro, não para a loja.
/// </summary>
public class Repasse : Entidade
{
    /// <summary>Comissão da XEPA sobre o valor dos produtos (modelo de negócio, seção de viabilidade).</summary>
    public const decimal PercentualComissao = 0.15m;

    public int EstabelecimentoId { get; set; }
    public Estabelecimento Estabelecimento { get; set; } = null!;

    public int QuantidadePedidos { get; set; }
    public decimal ValorVendas { get; set; }
    public decimal Comissao { get; set; }
    public decimal TaxasEntrega { get; set; }
    public decimal ValorLiquido { get; set; }

    public DateTimeOffset? PagoEm { get; set; }
    public bool Pago => PagoEm.HasValue;

    public List<Pedido> Pedidos { get; set; } = [];

    /// <summary>Fecha o repasse com os pedidos informados (todos entregues e ainda sem repasse).</summary>
    public static Repasse Fechar(int estabelecimentoId, IReadOnlyCollection<Pedido> pedidos)
    {
        if (pedidos.Count == 0)
            throw new RegraDeNegocioException("Não há pedidos entregues para repassar.");
        if (pedidos.Any(p => p.Status != StatusPedido.Entregue || p.RepasseId.HasValue))
            throw new RegraDeNegocioException("Só entram no repasse pedidos entregues e ainda não repassados.");

        var vendas = pedidos.Sum(p => p.PrecoUnitario * p.Quantidade);
        var comissao = Math.Round(vendas * PercentualComissao, 2, MidpointRounding.AwayFromZero);
        var taxas = pedidos.Sum(p => p.TaxaEntrega);

        var repasse = new Repasse
        {
            EstabelecimentoId = estabelecimentoId,
            QuantidadePedidos = pedidos.Count,
            ValorVendas = vendas,
            Comissao = comissao,
            TaxasEntrega = taxas,
            ValorLiquido = vendas - comissao
        };
        foreach (var pedido in pedidos)
            pedido.Repasse = repasse;
        return repasse;
    }

    public void MarcarPago(DateTimeOffset agora)
    {
        if (Pago)
            throw new RegraDeNegocioException("Este repasse já foi pago.");
        PagoEm = agora;
    }
}
