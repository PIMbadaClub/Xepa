using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Tests.Dominio;

public class PedidoTests
{
    private static Pedido NovoPedido(TipoEntrega tipo = TipoEntrega.Retirada, StatusPedido status = StatusPedido.AguardandoPagamento) =>
        new() { TipoEntrega = tipo, Status = status, CodigoRetirada = "4821" };

    [Fact]
    public void Pagamento_aprovado_libera_o_pedido_para_a_loja()
    {
        var pedido = NovoPedido();

        pedido.ConfirmarPagamento();

        Assert.Equal(StatusPedido.Pendente, pedido.Status);
    }

    [Fact]
    public void Webhook_repetido_nao_altera_o_pedido()
    {
        var pedido = NovoPedido(status: StatusPedido.Confirmado);

        pedido.ConfirmarPagamento();

        Assert.Equal(StatusPedido.Confirmado, pedido.Status);
    }

    [Theory]
    [InlineData(StatusPedido.AguardandoPagamento)]
    [InlineData(StatusPedido.Pendente)]
    public void Cliente_cancela_antes_da_confirmacao(StatusPedido status)
    {
        var pedido = NovoPedido(status: status);

        pedido.Cancelar();

        Assert.Equal(StatusPedido.Cancelado, pedido.Status);
    }

    [Theory]
    [InlineData(StatusPedido.Confirmado)]
    [InlineData(StatusPedido.EmPreparo)]
    [InlineData(StatusPedido.Entregue)]
    [InlineData(StatusPedido.Cancelado)]
    public void Nao_cancela_depois_da_confirmacao(StatusPedido status)
    {
        var pedido = NovoPedido(status: status);

        Assert.Throws<RegraDeNegocioException>(pedido.Cancelar);
        Assert.Equal(status, pedido.Status);
    }

    [Fact]
    public void Retirada_percorre_o_ciclo_ate_entregue_com_o_codigo()
    {
        var pedido = NovoPedido(status: StatusPedido.Pendente);

        pedido.AvancarStatus(StatusPedido.Confirmado);
        pedido.AvancarStatus(StatusPedido.EmPreparo);
        pedido.AvancarStatus(StatusPedido.ProntoParaRetirada);
        pedido.ConfirmarRetirada("4821");

        Assert.Equal(StatusPedido.Entregue, pedido.Status);
    }

    [Fact]
    public void Codigo_de_retirada_errado_e_recusado()
    {
        var pedido = NovoPedido(status: StatusPedido.ProntoParaRetirada);

        Assert.Throws<RegraDeNegocioException>(() => pedido.ConfirmarRetirada("0000"));
    }

    [Fact]
    public void Pedido_de_retirada_nao_sai_para_entrega()
    {
        var pedido = NovoPedido(TipoEntrega.Retirada, StatusPedido.EmPreparo);

        Assert.Throws<RegraDeNegocioException>(() => pedido.AvancarStatus(StatusPedido.SaiuParaEntrega));
    }

    [Fact]
    public void Entrega_so_sai_depois_de_a_loja_marcar_pronto()
    {
        var pedido = NovoPedido(TipoEntrega.Entrega, StatusPedido.EmPreparo);

        Assert.Throws<RegraDeNegocioException>(() => pedido.AvancarStatus(StatusPedido.SaiuParaEntrega));
        pedido.AvancarStatus(StatusPedido.ProntoParaRetirada);
        Assert.Throws<RegraDeNegocioException>(() => pedido.AvancarStatus(StatusPedido.Entregue));
        Assert.Throws<RegraDeNegocioException>(() => pedido.ConfirmarRetirada("4821"));
        pedido.AvancarStatus(StatusPedido.SaiuParaEntrega);
        pedido.AvancarStatus(StatusPedido.Entregue);
        Assert.Equal(StatusPedido.Entregue, pedido.Status);
    }

    [Fact]
    public void Nao_pula_etapas()
    {
        var pedido = NovoPedido(status: StatusPedido.Pendente);

        Assert.Throws<RegraDeNegocioException>(() => pedido.AvancarStatus(StatusPedido.Entregue));
    }

    [Fact]
    public void Cliente_avalia_o_entregador_depois_da_entrega()
    {
        var pedido = NovoPedido(TipoEntrega.Entrega, StatusPedido.Entregue);
        pedido.EntregadorId = 7;

        pedido.AvaliarEntregador(5, "  Rápido e educado ");

        Assert.Equal(5, pedido.NotaEntregador);
        Assert.Equal("Rápido e educado", pedido.ComentarioEntregador);
        Assert.NotNull(pedido.EntregadorAvaliadoEm);
    }

    [Fact]
    public void Entregador_so_e_avaliado_uma_vez_e_depois_de_entregue()
    {
        var aCaminho = NovoPedido(TipoEntrega.Entrega, StatusPedido.SaiuParaEntrega);
        aCaminho.EntregadorId = 7;
        Assert.Throws<RegraDeNegocioException>(() => aCaminho.AvaliarEntregador(5, null));

        var entregue = NovoPedido(TipoEntrega.Entrega, StatusPedido.Entregue);
        entregue.EntregadorId = 7;
        entregue.AvaliarEntregador(4, null);
        Assert.Throws<RegraDeNegocioException>(() => entregue.AvaliarEntregador(5, null));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(6)]
    public void Nota_do_entregador_vai_de_1_a_5(int nota)
    {
        var pedido = NovoPedido(TipoEntrega.Entrega, StatusPedido.Entregue);
        pedido.EntregadorId = 7;

        Assert.Throws<RegraDeNegocioException>(() => pedido.AvaliarEntregador(nota, null));
    }

    [Fact]
    public void Retirada_na_loja_nao_tem_entregador_para_avaliar()
    {
        var pedido = NovoPedido(TipoEntrega.Retirada, StatusPedido.Entregue);

        Assert.Throws<RegraDeNegocioException>(() => pedido.AvaliarEntregador(5, null));
    }
}
