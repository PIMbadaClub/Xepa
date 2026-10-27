using System.ComponentModel.DataAnnotations;
using Xepa.Application.Contas;
using Xepa.Application.Suporte;
using Xepa.Domain.Entities;

namespace Xepa.Tests.Dominio;

public class SuporteLgpdTests
{
    [Theory]
    [InlineData(11, true)]   // 8h em Brasília
    [InlineData(24, true)]   // 21h
    [InlineData(1, false)]   // 22h: fora do atendimento
    [InlineData(10, false)]  // 7h
    public void Atendimento_humano_das_8h_as_22h_de_Brasilia(int horaUtc, bool esperado)
    {
        var instante = new DateTimeOffset(2026, 10, 27, 0, 0, 0, TimeSpan.Zero).AddHours(horaUtc);
        Assert.Equal(esperado, SuporteService.AtendimentoAgora(instante));
    }

    private static List<ValidationResult> Validar(object modelo)
    {
        var erros = new List<ValidationResult>();
        Validator.TryValidateObject(modelo, new ValidationContext(modelo), erros, validateAllProperties: true);
        return erros;
    }

    [Fact]
    public void Cadastro_pelo_app_exige_aceite_dos_termos()
    {
        var sem = new RegistrarRequest { Nome = "Ana", Email = "ana@xepa.test", Senha = "senha-boa-123" };
        var com = new RegistrarRequest { Nome = "Ana", Email = "ana@xepa.test", Senha = "senha-boa-123", AceitouTermos = true };

        Assert.Contains(Validar(sem), e => e.MemberNames.Contains(nameof(RegistrarRequest.AceitouTermos)));
        Assert.Empty(Validar(com));
    }

    [Fact]
    public void Cadastro_da_loja_exige_aceite_dos_termos()
    {
        var form = new CadastroLojaForm { AceitouTermos = false };
        Assert.Contains(Validar(form), e => e.MemberNames.Contains(nameof(CadastroLojaForm.AceitouTermos)));

        form.AceitouTermos = true;
        Assert.DoesNotContain(Validar(form), e => e.MemberNames.Contains(nameof(CadastroLojaForm.AceitouTermos)));
    }

    [Fact]
    public void Mensagem_de_suporte_vazia_ou_longa_e_recusada()
    {
        Assert.NotEmpty(Validar(new EnviarMensagemSuporteRequest { Texto = "" }));
        Assert.NotEmpty(Validar(new EnviarMensagemSuporteRequest { Texto = new string('a', 2001) }));
        Assert.Empty(Validar(new EnviarMensagemSuporteRequest { Texto = "Meu pedido não chegou" }));
    }

    [Fact]
    public void Conversa_nova_comeca_aberta_e_sem_pendencias()
    {
        var conversa = new ConversaSuporte();
        Assert.Equal(StatusConversa.Aberta, conversa.Status);
        Assert.Equal(0, conversa.NaoLidasUsuario);
        Assert.Equal(0, conversa.NaoLidasSuporte);
    }
}
