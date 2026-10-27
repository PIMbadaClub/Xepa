-- Horário de funcionamento das lojas de demonstração de Limeira (só para quem ainda não cadastrou).
-- Padarias e mercados abrem cedo; restaurantes no almoço e à noite (um intervalo por dia: 11h às 23h).
-- Rodar com: sqlcmd -I -f 65001 ... -i horarios-demo.sql
SET NOCOUNT ON;

DECLARE @dias TABLE (Dia int);
INSERT INTO @dias VALUES (0), (1), (2), (3), (4), (5), (6); -- 0 = domingo, como o DayOfWeek do .NET

INSERT INTO HorariosFuncionamento (EstabelecimentoId, DiaSemana, Abre, Fecha)
SELECT e.Id, d.Dia,
       CASE WHEN e.Categoria = 'Restaurante' THEN '11:00'
            WHEN d.Dia = 0 THEN '07:00'
            ELSE '06:30' END,
       CASE WHEN e.Categoria = 'Restaurante' THEN '23:00'
            WHEN d.Dia = 0 THEN '13:00'
            ELSE '20:30' END
FROM Estabelecimentos e
CROSS JOIN @dias d
WHERE e.Cidade = N'Limeira'
  AND NOT EXISTS (SELECT 1 FROM HorariosFuncionamento h WHERE h.EstabelecimentoId = e.Id)
  -- Feiras não abrem segunda.
  AND NOT (e.Categoria = 'Feira' AND d.Dia = 1);

SELECT COUNT(DISTINCT EstabelecimentoId) AS LojasComHorario FROM HorariosFuncionamento;
