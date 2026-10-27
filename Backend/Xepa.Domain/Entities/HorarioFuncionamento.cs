namespace Xepa.Domain.Entities;

/// <summary>
/// Horário em que a loja abre num dia da semana (horário de Brasília). Dia sem registro = loja fechada.
/// Fechar depois da meia-noite não é suportado: "Fecha" precisa ser depois de "Abre" no mesmo dia.
/// </summary>
public class HorarioFuncionamento
{
    public int Id { get; set; }
    public int EstabelecimentoId { get; set; }
    public DayOfWeek DiaSemana { get; set; }
    public TimeOnly Abre { get; set; }
    public TimeOnly Fecha { get; set; }

    public bool Contem(TimeOnly hora) => hora >= Abre && hora < Fecha;
}

/// <summary>Situação de funcionamento num instante: aberto ou não e o próximo horário relevante.</summary>
public record SituacaoFuncionamento(bool TemHorario, bool Aberta, string Texto);

public static class Funcionamento
{
    private static readonly string[] NomesDias = ["domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"];

    public static string NomeDia(DayOfWeek dia) => NomesDias[(int)dia];

    /// <summary>
    /// "Aberta · fecha às 20:00", "Fechada · abre às 07:00", "Fechada · abre segunda às 07:00".
    /// <paramref name="agoraLocal"/> é o horário de Brasília.
    /// </summary>
    public static SituacaoFuncionamento Situacao(IReadOnlyCollection<HorarioFuncionamento> horarios, DateTime agoraLocal)
    {
        if (horarios.Count == 0)
            return new SituacaoFuncionamento(false, false, "Horário não informado");

        var hora = TimeOnly.FromDateTime(agoraLocal);
        var hoje = horarios.Where(h => h.DiaSemana == agoraLocal.DayOfWeek).OrderBy(h => h.Abre).ToList();
        var aberto = hoje.FirstOrDefault(h => h.Contem(hora));
        if (aberto is not null)
            return new SituacaoFuncionamento(true, true, $"Aberta · fecha às {aberto.Fecha:HH\\:mm}");

        var maisTarde = hoje.FirstOrDefault(h => h.Abre > hora);
        if (maisTarde is not null)
            return new SituacaoFuncionamento(true, false, $"Fechada · abre às {maisTarde.Abre:HH\\:mm}");

        for (var i = 1; i <= 7; i++)
        {
            var dia = agoraLocal.AddDays(i).DayOfWeek;
            var proximo = horarios.Where(h => h.DiaSemana == dia).OrderBy(h => h.Abre).FirstOrDefault();
            if (proximo is not null)
                return new SituacaoFuncionamento(true, false,
                    $"Fechada · abre {(i == 1 ? "amanhã" : NomeDia(dia))} às {proximo.Abre:HH\\:mm}");
        }
        return new SituacaoFuncionamento(true, false, "Fechada");
    }
}
