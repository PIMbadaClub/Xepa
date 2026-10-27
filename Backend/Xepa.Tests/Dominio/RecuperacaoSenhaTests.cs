using Xepa.Domain.Entities;

namespace Xepa.Tests.Dominio;

public class RecuperacaoSenhaTests
{
    private static readonly DateTimeOffset Agora = new(2026, 10, 26, 12, 0, 0, TimeSpan.Zero);

    private static CodigoRecuperacaoSenha Codigo() => new()
    {
        CodigoHash = "x",
        CriadoEm = Agora,
        ExpiraEm = Agora + CodigoRecuperacaoSenha.Validade
    };

    [Fact]
    public void Codigo_vale_por_15_minutos()
    {
        var codigo = Codigo();

        Assert.True(codigo.Valido(Agora.AddMinutes(14)));
        Assert.False(codigo.Valido(Agora.AddMinutes(16)));
    }

    [Fact]
    public void Codigo_usado_nao_vale_de_novo()
    {
        var codigo = Codigo();
        codigo.UsadoEm = Agora;

        Assert.False(codigo.Valido(Agora.AddMinutes(1)));
    }

    [Fact]
    public void Cinco_tentativas_erradas_invalidam_o_codigo()
    {
        var codigo = Codigo();
        codigo.Tentativas = CodigoRecuperacaoSenha.MaximoTentativas - 1;
        Assert.True(codigo.Valido(Agora));

        codigo.Tentativas++;
        Assert.False(codigo.Valido(Agora));
    }
}
