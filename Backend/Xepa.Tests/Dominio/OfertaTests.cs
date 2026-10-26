using Xepa.Application;
using Xepa.Domain;
using Xepa.Domain.Entities;
using Xepa.Infrastructure;

namespace Xepa.Tests.Dominio;

public class OfertaTests
{
    private static Oferta NovaOferta(int quantidade = 3, bool ativa = true, int horasAteFim = 2) => new()
    {
        Titulo = "Sacola surpresa",
        PrecoOriginal = 36m,
        Preco = 12.90m,
        QuantidadeDisponivel = quantidade,
        Ativa = ativa,
        RetiradaInicio = DateTimeOffset.UtcNow.AddHours(-1),
        RetiradaFim = DateTimeOffset.UtcNow.AddHours(horasAteFim)
    };

    [Fact]
    public void Reservar_desconta_do_estoque()
    {
        var oferta = NovaOferta(quantidade: 3);

        oferta.Reservar(2);

        Assert.Equal(1, oferta.QuantidadeDisponivel);
    }

    [Fact]
    public void Nao_reserva_mais_que_o_disponivel()
    {
        var oferta = NovaOferta(quantidade: 1);

        var erro = Assert.Throws<RegraDeNegocioException>(() => oferta.Reservar(2));
        Assert.Contains("disponível", erro.Message);
        Assert.Equal(1, oferta.QuantidadeDisponivel);
    }

    [Fact]
    public void Nao_reserva_oferta_inativa_ou_vencida()
    {
        Assert.Throws<RegraDeNegocioException>(() => NovaOferta(ativa: false).Reservar(1));
        Assert.Throws<RegraDeNegocioException>(() => NovaOferta(horasAteFim: -1).Reservar(1));
    }

    [Fact]
    public void Devolver_repoe_o_estoque()
    {
        var oferta = NovaOferta(quantidade: 0);

        oferta.Devolver(2);

        Assert.Equal(2, oferta.QuantidadeDisponivel);
    }

    [Theory]
    [InlineData(36, 36)]
    [InlineData(36, 40)]
    [InlineData(36, 0)]
    public void Preco_com_desconto_precisa_ser_menor_que_o_original(decimal original, decimal preco)
    {
        var oferta = NovaOferta();
        oferta.PrecoOriginal = original;
        oferta.Preco = preco;

        Assert.Throws<RegraDeNegocioException>(oferta.Validar);
    }

    [Fact]
    public void Janela_de_retirada_precisa_terminar_depois_de_comecar()
    {
        var oferta = NovaOferta();
        oferta.RetiradaFim = oferta.RetiradaInicio;

        Assert.Throws<RegraDeNegocioException>(oferta.Validar);
    }

    [Fact]
    public void Desativar_loja_tira_as_ofertas_do_ar()
    {
        var loja = new Estabelecimento
        {
            Nome = "Padaria",
            StatusCadastro = StatusCadastro.Aprovado,
            Endereco = new Endereco { Cep = "13480000", Logradouro = "Rua", Numero = "1", Bairro = "Centro", Cidade = "Limeira", Uf = "SP" },
            Ofertas = [NovaOferta(), NovaOferta()]
        };

        loja.Desativar();

        Assert.False(loja.VisivelNoApp);
        Assert.All(loja.Ofertas, o => Assert.False(o.Ativa));
    }
}

public class EntregaTests
{
    [Theory]
    [InlineData(0, 3.00)]
    [InlineData(2, 6.00)]
    [InlineData(5, 10.50)]
    public void Taxa_e_fixa_mais_valor_por_km(double km, decimal esperado) =>
        Assert.Equal(esperado, RegrasEntrega.CalcularTaxa(km));

    [Fact]
    public void Entrega_acima_do_raio_e_recusada() =>
        Assert.Throws<RegraDeNegocioException>(() => RegrasEntrega.CalcularTaxa(5.01));

    [Fact]
    public async Task Rota_estimada_entre_dois_pontos_proximos()
    {
        // Av. Paulista até a Praça da Sé: cerca de 3 km em linha reta.
        var rota = await new MapasEstimados().CalcularRotaAsync(
            new Coordenada(-23.5614, -46.6559), new Coordenada(-23.5505, -46.6333), CancellationToken.None);

        Assert.InRange(rota.DistanciaKm, 3.0, 4.0);
        Assert.True(rota.MinutosEstimados > 0);
    }
}

public class SenhaTests
{
    [Fact]
    public void Hash_confere_so_a_senha_certa()
    {
        var hasher = new HasherSenha();
        var usuario = new Usuario { Nome = "Ana", Email = "ana@xepa.test", SenhaHash = "" };
        usuario.SenhaHash = hasher.Gerar(usuario, "SenhaForte1");

        Assert.NotEqual("SenhaForte1", usuario.SenhaHash);
        Assert.True(hasher.Conferir(usuario, "SenhaForte1"));
        Assert.False(hasher.Conferir(usuario, "senhaforte1"));
    }
}
