-- Ajuste único da homologação: os dados de demonstração nasceram em São Paulo e passam para Limeira-SP.
-- As 4 lojas demo mudam de endereço (têm pedidos, denúncia e repasse no histórico, por isso não são apagadas)
-- e os endereços de entrega fora de Limeira são apagados. Os pedidos guardam cópia do endereço (RN04).
SET NOCOUNT ON; SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @agora datetimeoffset = SYSDATETIMEOFFSET();

UPDATE e SET Logradouro = v.Logradouro, Numero = v.Numero, Bairro = N'Centro', Cidade = N'Limeira', Uf = 'SP',
             Cep = '13480000', Complemento = NULL, Latitude = v.Lat, Longitude = v.Lon, AtualizadoEm = @agora
FROM Estabelecimentos e
JOIN Usuarios u ON u.Id = e.UsuarioId
JOIN (VALUES
    ('padaria@xepa.test', N'Rua Senador Vergueiro', '400', -22.56257, -47.40107),
    ('cantina@xepa.test', N'Rua Santa Cruz',        '300', -22.56065, -47.40049),
    ('feira@xepa.test',   N'Rua Boa Morte',         '400', -22.56581, -47.40154),
    ('mercado@xepa.test', N'Rua Carlos Gomes',      '400', -22.56446, -47.40171)
) v (Email, Logradouro, Numero, Lat, Lon) ON v.Email = u.Email;
PRINT CONCAT(@@ROWCOUNT, ' loja(s) demo movida(s) para Limeira');

-- Garante que todo cliente com endereço fora de Limeira continue com um principal, se tiver um em Limeira.
DELETE FROM Enderecos WHERE Cidade <> N'Limeira';
PRINT CONCAT(@@ROWCOUNT, ' endereço(s) fora de Limeira apagado(s)');
UPDATE en SET Principal = 1
FROM Enderecos en
WHERE NOT EXISTS (SELECT 1 FROM Enderecos x WHERE x.UsuarioId = en.UsuarioId AND x.Principal = 1)
  AND en.Id = (SELECT MIN(y.Id) FROM Enderecos y WHERE y.UsuarioId = en.UsuarioId);

-- Ofertas das lojas demo voltam a valer hoje, como as de Limeira.
DECLARE @local datetimeoffset = @agora AT TIME ZONE 'E. South America Standard Time';
DECLARE @dia date = CASE WHEN DATEPART(hour, @local) >= 22 THEN DATEADD(day, 1, CAST(@local AS date)) ELSE CAST(@local AS date) END;
DECLARE @inicio datetimeoffset = CASE WHEN @dia > CAST(@local AS date) THEN TODATETIMEOFFSET(DATEADD(hour, 11, CAST(@dia AS datetime2)), '-03:00') ELSE DATEADD(minute, -5, @agora) END;
DECLARE @fim datetimeoffset = TODATETIMEOFFSET(DATEADD(minute, 1410, CAST(@dia AS datetime2)), '-03:00');
UPDATE o SET RetiradaInicio = @inicio, RetiradaFim = @fim,
             QuantidadeDisponivel = CASE WHEN o.QuantidadeDisponivel < 2 THEN 3 ELSE o.QuantidadeDisponivel END, AtualizadoEm = @agora
FROM Ofertas o
JOIN Estabelecimentos e ON e.Id = o.EstabelecimentoId
JOIN Usuarios u ON u.Id = e.UsuarioId
WHERE o.Ativa = 1 AND u.Email IN ('padaria@xepa.test', 'cantina@xepa.test', 'feira@xepa.test', 'mercado@xepa.test');

COMMIT;
SELECT Cidade, COUNT(*) AS Lojas FROM Estabelecimentos GROUP BY Cidade;
SELECT u.Email, en.Apelido, en.Cidade, en.Principal FROM Enderecos en JOIN Usuarios u ON u.Id = en.UsuarioId;
