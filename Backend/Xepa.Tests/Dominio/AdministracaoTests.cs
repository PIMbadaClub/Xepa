using Xepa.Application.Contas;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Tests.Dominio;

public class RepasseTests
{
    private static Pedido Entregue(decimal preco, int quantidade, decimal taxa = 0) => new()
    {
        Status = StatusPedido.Entregue,
        PrecoUnitario = preco,
        Quantidade = quantidade,
        TaxaEntrega = taxa
    };

    [Fact]
    public void Retem_15_por_cento_dos_produtos_e_repassa_a_taxa_de_entrega()
    {
        var pedidos = new[] { Entregue(12.90m, 2), Entregue(15.90m, 1, taxa: 3.60m) };

        var repasse = Repasse.Fechar(7, pedidos);

        Assert.Equal(41.70m, repasse.ValorVendas);
        Assert.Equal(6.26m, repasse.Comissao);          // 15% de 41,70 = 6,255, arredonda para cima
        Assert.Equal(3.60m, repasse.TaxasEntrega);
        Assert.Equal(39.04m, repasse.ValorLiquido);     // 41,70 - 6,26 + 3,60
        Assert.Equal(2, repasse.QuantidadePedidos);
        Assert.All(pedidos, p => Assert.Same(repasse, p.Repasse));
    }

    [Fact]
    public void Nao_fecha_sem_pedidos() =>
        Assert.Throws<RegraDeNegocioException>(() => Repasse.Fechar(7, []));

    [Fact]
    public void Nao_inclui_pedido_nao_entregue_ou_ja_repassado()
    {
        var emPreparo = Entregue(10m, 1);
        emPreparo.Status = StatusPedido.EmPreparo;
        Assert.Throws<RegraDeNegocioException>(() => Repasse.Fechar(7, [emPreparo]));

        var jaRepassado = Entregue(10m, 1);
        jaRepassado.RepasseId = 3;
        Assert.Throws<RegraDeNegocioException>(() => Repasse.Fechar(7, [jaRepassado]));
    }

    [Fact]
    public void So_paga_uma_vez()
    {
        var repasse = Repasse.Fechar(7, [Entregue(10m, 1)]);
        repasse.MarcarPago(DateTimeOffset.UtcNow);
        Assert.True(repasse.Pago);
        Assert.Throws<RegraDeNegocioException>(() => repasse.MarcarPago(DateTimeOffset.UtcNow));
    }
}

public class DenunciaTests
{
    private static Denuncia Nova() => new() { Descricao = "A sacola veio com pão mofado.", Motivo = MotivoDenuncia.ComidaImpropria };

    [Fact]
    public void Tratar_registra_decisao_resposta_e_responsavel()
    {
        var d = Nova();
        var agora = DateTimeOffset.UtcNow;

        d.Tratar(StatusDenuncia.Procedente, "  Valor estornado e loja advertida.  ", administradorId: 2, agora);

        Assert.Equal(StatusDenuncia.Procedente, d.Status);
        Assert.Equal("Valor estornado e loja advertida.", d.Resposta);
        Assert.Equal(2, d.TratadaPorId);
        Assert.Equal(agora, d.TratadaEm);
    }

    [Fact]
    public void Exige_resposta_e_decisao_valida()
    {
        Assert.Throws<RegraDeNegocioException>(() => Nova().Tratar(StatusDenuncia.Procedente, " ", 2, DateTimeOffset.UtcNow));
        Assert.Throws<RegraDeNegocioException>(() => Nova().Tratar(StatusDenuncia.Aberta, "ok", 2, DateTimeOffset.UtcNow));
    }

    [Fact]
    public void Nao_trata_duas_vezes()
    {
        var d = Nova();
        d.Tratar(StatusDenuncia.Improcedente, "Pedido entregue conforme o anúncio.", 2, DateTimeOffset.UtcNow);
        Assert.Throws<RegraDeNegocioException>(() => d.Tratar(StatusDenuncia.Procedente, "mudei de ideia", 2, DateTimeOffset.UtcNow));
    }
}

public class CnpjTests
{
    [Theory]
    [InlineData("11222333000181")]
    [InlineData("11444777000161")]
    public void Aceita_cnpj_com_digitos_corretos(string cnpj) => Assert.True(CadastroLojaService.CnpjValido(cnpj));

    [Theory]
    [InlineData("11222333000182")]
    [InlineData("00000000000000")]
    [InlineData("1122233300018")]
    public void Recusa_cnpj_invalido(string cnpj) => Assert.False(CadastroLojaService.CnpjValido(cnpj));
}
