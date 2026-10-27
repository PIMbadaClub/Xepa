namespace Xepa.Domain.Entities;

/// <summary>
/// Valor que a XEPA deve ao entregador parceiro: a soma das taxas de entrega das corridas que ele concluiu.
/// A taxa é paga pelo cliente e vai inteira para o entregador (sem comissão).
/// </summary>
public class RepasseEntregador : Entidade
{
    public int EntregadorId { get; set; }
    public Usuario Entregador { get; set; } = null!;

    public int QuantidadeCorridas { get; set; }
    public double KmTotal { get; set; }
    public decimal Valor { get; set; }

    public DateTimeOffset? PagoEm { get; set; }
    public bool Pago => PagoEm.HasValue;

    public List<Pedido> Pedidos { get; set; } = [];

    /// <summary>Fecha o repasse com as corridas informadas (todas entregues por ele e ainda sem repasse).</summary>
    public static RepasseEntregador Fechar(int entregadorId, IReadOnlyCollection<Pedido> corridas)
    {
        if (corridas.Count == 0)
            throw new RegraDeNegocioException("Não há corridas entregues para repassar.");
        if (corridas.Any(p => p.Status != StatusPedido.Entregue || p.EntregadorId != entregadorId || p.RepasseEntregadorId.HasValue))
            throw new RegraDeNegocioException("Só entram no repasse corridas entregues por este entregador e ainda não repassadas.");

        var repasse = new RepasseEntregador
        {
            EntregadorId = entregadorId,
            QuantidadeCorridas = corridas.Count,
            KmTotal = Math.Round(corridas.Sum(p => p.DistanciaEntregaKm ?? 0), 1),
            Valor = corridas.Sum(p => p.TaxaEntrega)
        };
        foreach (var corrida in corridas)
            corrida.RepasseEntregador = repasse;
        return repasse;
    }

    public void MarcarPago(DateTimeOffset agora)
    {
        if (Pago)
            throw new RegraDeNegocioException("Este repasse já foi pago.");
        PagoEm = agora;
    }
}
