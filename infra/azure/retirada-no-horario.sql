-- Corta a retirada das ofertas no ar no fechamento da loja naquele dia (horário de Brasília).
-- A carga de demonstração usa 11h–23h30 para todas; sem isto o app anuncia retirada com a loja fechada.
-- Rodar depois de dados-limeira.sql e horarios-demo.sql: sqlcmd -I -f 65001 ... -i retirada-no-horario.sql
SET NOCOUNT ON;

WITH alvo AS (
    SELECT o.Id,
           TODATETIMEOFFSET(DATEADD(minute, DATEDIFF(minute, '00:00', h.Fecha),
                            CAST(CAST(SWITCHOFFSET(o.RetiradaInicio, '-03:00') AS date) AS datetime2)), '-03:00') AS Fechamento
    FROM Ofertas o
    JOIN HorariosFuncionamento h ON h.EstabelecimentoId = o.EstabelecimentoId
         AND h.DiaSemana = (DATEPART(weekday, SWITCHOFFSET(o.RetiradaInicio, '-03:00')) + @@DATEFIRST - 1) % 7 -- 0 = domingo
    WHERE o.Ativa = 1 AND o.RetiradaFim > SYSDATETIMEOFFSET()
)
UPDATE o SET RetiradaFim = a.Fechamento
FROM Ofertas o JOIN alvo a ON a.Id = o.Id
WHERE o.RetiradaFim > a.Fechamento AND o.RetiradaInicio < a.Fechamento;

SELECT @@ROWCOUNT AS OfertasAjustadas;
