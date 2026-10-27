using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Tests.Dominio;

public class AvaliacaoRepasseEntregadorTests
{
    private static Pedido Entregue(TipoEntrega tipo = TipoEntrega.Entrega, int? entregador = 7, decimal taxa = 6m, double km = 2) =>
        new() { TipoEntrega = tipo, Status = StatusPedido.Entregue, EntregadorId = entregador, TaxaEntrega = taxa, DistanciaEntregaKm = km };

    [Fact]
    public void Cliente_avalia_a_loja_tambem_na_retirada()
    {
        var pedido = Entregue(TipoEntrega.Retirada, entregador: null);

        pedido.AvaliarLoja(4, " Pão ainda quentinho ");

        Assert.Equal(4, pedido.NotaLoja);
        Assert.Equal("Pão ainda quentinho", pedido.ComentarioLoja);
        Assert.Throws<RegraDeNegocioException>(() => pedido.AvaliarLoja(5, null));
    }

    [Fact]
    public void Loja_so_e_avaliada_depois_de_entregue()
    {
        var pedido = new Pedido { Status = StatusPedido.EmPreparo };

        Assert.Throws<RegraDeNegocioException>(() => pedido.AvaliarLoja(5, null));
    }

    [Fact]
    public void Repasse_do_entregador_soma_as_taxas_e_os_km()
    {
        var corridas = new[] { Entregue(taxa: 6m, km: 2), Entregue(taxa: 7.5m, km: 3.04) };

        var repasse = RepasseEntregador.Fechar(7, corridas);

        Assert.Equal(13.5m, repasse.Valor);
        Assert.Equal(2, repasse.QuantidadeCorridas);
        Assert.Equal(5.0, repasse.KmTotal);
        Assert.All(corridas, c => Assert.Same(repasse, c.RepasseEntregador));
    }

    [Fact]
    public void Repasse_do_entregador_recusa_corrida_de_outro_ou_ja_repassada()
    {
        Assert.Throws<RegraDeNegocioException>(() => RepasseEntregador.Fechar(7, [Entregue(entregador: 8)]));
        var repassada = Entregue();
        repassada.RepasseEntregadorId = 1;
        Assert.Throws<RegraDeNegocioException>(() => RepasseEntregador.Fechar(7, [repassada]));
        Assert.Throws<RegraDeNegocioException>(() => RepasseEntregador.Fechar(7, []));
    }

    [Fact]
    public void Repasse_do_entregador_nao_e_pago_duas_vezes()
    {
        var repasse = RepasseEntregador.Fechar(7, [Entregue()]);
        repasse.MarcarPago(DateTimeOffset.UtcNow);

        Assert.Throws<RegraDeNegocioException>(() => repasse.MarcarPago(DateTimeOffset.UtcNow));
    }
}
