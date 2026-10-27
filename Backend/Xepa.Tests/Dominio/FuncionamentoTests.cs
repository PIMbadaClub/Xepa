using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Tests.Dominio;

public class FuncionamentoTests
{
    // 27/10/2026 é uma terça-feira.
    private static readonly DateTime TercaDezHoras = new(2026, 10, 27, 10, 0, 0);

    private static HorarioFuncionamento Dia(DayOfWeek dia, int abre, int fecha) =>
        new() { DiaSemana = dia, Abre = new TimeOnly(abre, 0), Fecha = new TimeOnly(fecha, 0) };

    [Fact]
    public void Aberta_mostra_quando_fecha()
    {
        var s = Funcionamento.Situacao([Dia(DayOfWeek.Tuesday, 7, 20)], TercaDezHoras);

        Assert.True(s.Aberta);
        Assert.Equal("Aberta · fecha às 20:00", s.Texto);
    }

    [Fact]
    public void Antes_de_abrir_mostra_a_hora_de_hoje()
    {
        var s = Funcionamento.Situacao([Dia(DayOfWeek.Tuesday, 15, 22)], TercaDezHoras);

        Assert.False(s.Aberta);
        Assert.Equal("Fechada · abre às 15:00", s.Texto);
    }

    [Fact]
    public void Depois_de_fechar_mostra_o_proximo_dia_aberto()
    {
        var horarios = new[] { Dia(DayOfWeek.Tuesday, 7, 9), Dia(DayOfWeek.Wednesday, 8, 18), Dia(DayOfWeek.Friday, 6, 12) };

        Assert.Equal("Fechada · abre amanhã às 08:00", Funcionamento.Situacao(horarios, TercaDezHoras).Texto);
        Assert.Equal("Fechada · abre sexta às 06:00", Funcionamento.Situacao(horarios, TercaDezHoras.AddDays(1).AddHours(9)).Texto);
    }

    [Fact]
    public void Sem_horario_cadastrado_nao_diz_se_esta_aberta()
    {
        var s = Funcionamento.Situacao([], TercaDezHoras);

        Assert.False(s.TemHorario);
    }

    [Fact]
    public void Horario_da_loja_recusa_fechar_antes_de_abrir_e_dia_repetido()
    {
        var loja = new Estabelecimento { Nome = "Padaria", Endereco = new Endereco { Cep = "13480000", Logradouro = "R", Numero = "1", Bairro = "B", Cidade = "Limeira", Uf = "SP" } };

        Assert.Throws<RegraDeNegocioException>(() => loja.DefinirHorarios([(DayOfWeek.Monday, new TimeOnly(18, 0), new TimeOnly(8, 0))]));
        Assert.Throws<RegraDeNegocioException>(() => loja.DefinirHorarios(
            [(DayOfWeek.Monday, new TimeOnly(8, 0), new TimeOnly(12, 0)), (DayOfWeek.Monday, new TimeOnly(14, 0), new TimeOnly(18, 0))]));

        loja.DefinirHorarios([(DayOfWeek.Saturday, new TimeOnly(7, 0), new TimeOnly(13, 0)), (DayOfWeek.Monday, new TimeOnly(6, 30), new TimeOnly(20, 0))]);
        Assert.Equal([DayOfWeek.Monday, DayOfWeek.Saturday], loja.Horarios.Select(h => h.DiaSemana));
    }

    [Fact]
    public void Loja_pausada_some_do_app()
    {
        var loja = new Estabelecimento { Nome = "Padaria", StatusCadastro = StatusCadastro.Aprovado, Endereco = null! };
        Assert.True(loja.VisivelNoApp);

        loja.Pausada = true;

        Assert.False(loja.VisivelNoApp);
    }
}
