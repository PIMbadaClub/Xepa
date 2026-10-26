using System.Security.Cryptography;
using System.Text;
using Xepa.Domain;
using Xepa.Domain.Entities;
using Xepa.Infrastructure.Integracoes;

namespace Xepa.Tests.Integracoes;

public class AssinaturaWebhookTests
{
    private const string Segredo = "segredo-do-painel";

    private static string Assinar(string dataId, string requestId, string ts)
    {
        var manifesto = $"id:{dataId};request-id:{requestId};ts:{ts};";
        var v1 = Convert.ToHexStringLower(HMACSHA256.HashData(Encoding.UTF8.GetBytes(Segredo), Encoding.UTF8.GetBytes(manifesto)));
        return $"ts={ts},v1={v1}";
    }

    [Fact]
    public void Assinatura_correta_e_aceita() =>
        Assert.True(GatewayMercadoPago.AssinaturaValida(Segredo, Assinar("123456", "req-1", "1730000000"), "req-1", "123456"));

    [Fact]
    public void Assinatura_de_outro_pagamento_e_recusada() =>
        Assert.False(GatewayMercadoPago.AssinaturaValida(Segredo, Assinar("123456", "req-1", "1730000000"), "req-1", "999999"));

    [Fact]
    public void Segredo_errado_e_recusado() =>
        Assert.False(GatewayMercadoPago.AssinaturaValida("outro", Assinar("123456", "req-1", "1730000000"), "req-1", "123456"));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("ts=1730000000")]
    [InlineData("lixo")]
    public void Cabecalho_ausente_ou_malformado_e_recusado(string? cabecalho) =>
        Assert.False(GatewayMercadoPago.AssinaturaValida(Segredo, cabecalho, "req-1", "123456"));
}

public class GatewaySimuladoTests
{
    private static Pedido NovoPedido() => new()
    {
        Id = 10, Quantidade = 1, ValorTotal = 16.68m, Oferta = new Oferta { Titulo = "Sacola" }
    };

    [Fact]
    public async Task Pix_simulado_fica_pendente_ate_ser_aprovado()
    {
        var gateway = new GatewaySimulado();
        var cobranca = await gateway.CriarCobrancaAsync(NovoPedido(), MetodoPagamento.Pix, "a@b.c", CancellationToken.None);

        Assert.StartsWith("SIM-", cobranca.IdExterno);
        Assert.Contains("BR.GOV.BCB.PIX", cobranca.QrCodePix);
        Assert.Equal(StatusPagamento.Pendente, (await gateway.ConsultarAsync(cobranca.IdExterno, CancellationToken.None))!.Status);

        Assert.True(gateway.Aprovar(cobranca.IdExterno));
        var situacao = await gateway.ConsultarAsync(cobranca.IdExterno, CancellationToken.None);
        Assert.Equal(StatusPagamento.Aprovado, situacao!.Status);
        Assert.Equal(10, situacao.PedidoId);
    }

    [Fact]
    public async Task Pagamento_desconhecido_retorna_nulo() =>
        Assert.Null(await new GatewaySimulado().ConsultarAsync("nao-existe", CancellationToken.None));
}

public class PagamentoEntidadeTests
{
    private static Pagamento Novo() => new() { IdExterno = "1", Valor = 10m };

    [Fact]
    public void Aprovacao_repetida_mantem_a_primeira_data()
    {
        var p = Novo();
        var primeira = DateTimeOffset.UtcNow.AddMinutes(-5);
        p.Aprovar(primeira);
        p.Aprovar(DateTimeOffset.UtcNow);

        Assert.Equal(StatusPagamento.Aprovado, p.Status);
        Assert.Equal(primeira, p.PagoEm);
    }

    [Fact]
    public void So_estorna_pagamento_aprovado()
    {
        var p = Novo();
        Assert.Throws<RegraDeNegocioException>(p.MarcarEstornado);

        p.Aprovar(DateTimeOffset.UtcNow);
        p.MarcarEstornado();
        Assert.Equal(StatusPagamento.Estornado, p.Status);
    }

    [Fact]
    public void Cobranca_vencida_nao_e_reaproveitada()
    {
        var p = Novo();
        p.ExpiraEm = DateTimeOffset.UtcNow.AddMinutes(-1);
        Assert.False(p.Vigente(DateTimeOffset.UtcNow));
    }
}
