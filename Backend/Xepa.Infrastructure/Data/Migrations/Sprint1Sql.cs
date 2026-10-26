namespace Xepa.Infrastructure.Data.Migrations;

/// <summary>
/// Procedures e triggers criados pela migration Sprint1PagamentosEntregaContas.
/// Uma alteração futura deve ir numa migration nova (CREATE OR ALTER), não aqui.
/// </summary>
internal static class Sprint1Sql
{
    /// <summary>Registra cada mudança de status e devolve o estoque quando o pedido é cancelado (RN03, RN05).</summary>
    public const string TriggerPedidosStatus = """
        CREATE OR ALTER TRIGGER dbo.trg_Pedidos_Status ON dbo.Pedidos
        AFTER INSERT, UPDATE
        AS
        BEGIN
            SET NOCOUNT ON;
            IF NOT UPDATE(Status) RETURN;

            INSERT INTO dbo.PedidosHistoricoStatus (PedidoId, StatusAnterior, StatusNovo, AlteradoEm)
            SELECT i.Id, d.Status, i.Status, SYSDATETIMEOFFSET()
            FROM inserted i
            LEFT JOIN deleted d ON d.Id = i.Id
            WHERE d.Id IS NULL OR d.Status <> i.Status;

            UPDATE o
               SET o.QuantidadeDisponivel = o.QuantidadeDisponivel + c.Quantidade,
                   o.AtualizadoEm = SYSDATETIMEOFFSET()
            FROM dbo.Ofertas o
            JOIN (SELECT i.OfertaId, SUM(i.Quantidade) AS Quantidade
                  FROM inserted i
                  JOIN deleted d ON d.Id = i.Id
                  WHERE i.Status = N'Cancelado' AND d.Status <> N'Cancelado'
                  GROUP BY i.OfertaId) c ON c.OfertaId = o.Id;
        END;
        """;

    /// <summary>Estabelecimento desativado tira todas as suas ofertas do ar.</summary>
    public const string TriggerEstabelecimentosDesativacao = """
        CREATE OR ALTER TRIGGER dbo.trg_Estabelecimentos_Desativacao ON dbo.Estabelecimentos
        AFTER UPDATE
        AS
        BEGIN
            SET NOCOUNT ON;
            IF NOT UPDATE(Ativo) RETURN;

            UPDATE o
               SET o.Ativa = 0, o.AtualizadoEm = SYSDATETIMEOFFSET()
            FROM dbo.Ofertas o
            JOIN inserted i ON i.Id = o.EstabelecimentoId
            JOIN deleted d ON d.Id = i.Id
            WHERE d.Ativo = 1 AND i.Ativo = 0 AND o.Ativa = 1;
        END;
        """;

    /// <summary>Oferta com pedidos não é apagada fisicamente: o DELETE vira desativação (RN06).</summary>
    public const string TriggerOfertasRemocaoLogica = """
        CREATE OR ALTER TRIGGER dbo.trg_Ofertas_RemocaoLogica ON dbo.Ofertas
        INSTEAD OF DELETE
        AS
        BEGIN
            SET NOCOUNT ON;

            UPDATE o SET o.Ativa = 0, o.AtualizadoEm = SYSDATETIMEOFFSET()
            FROM dbo.Ofertas o
            JOIN deleted d ON d.Id = o.Id
            WHERE EXISTS (SELECT 1 FROM dbo.Pedidos p WHERE p.OfertaId = d.Id);

            DELETE o
            FROM dbo.Ofertas o
            JOIN deleted d ON d.Id = o.Id
            WHERE NOT EXISTS (SELECT 1 FROM dbo.Pedidos p WHERE p.OfertaId = d.Id);
        END;
        """;

    /// <summary>Cria o pedido reservando o estoque na mesma transação (RN01, RN03, RN04).</summary>
    public const string ProcCriarPedido = """
        CREATE OR ALTER PROCEDURE dbo.sp_CriarPedido
            @ClienteId    INT,
            @OfertaId     INT,
            @Quantidade   INT,
            @TipoEntrega  NVARCHAR(20),
            @TaxaEntrega  DECIMAL(10,2) = 0,
            @EnderecoId   INT = NULL,
            @PedidoId     INT OUTPUT
        AS
        BEGIN
            SET NOCOUNT ON;
            SET XACT_ABORT ON;

            BEGIN TRY
                BEGIN TRANSACTION;

                DECLARE @Preco DECIMAL(10,2), @Disponivel INT, @Agora DATETIMEOFFSET = SYSDATETIMEOFFSET();

                SELECT @Preco = o.Preco, @Disponivel = o.QuantidadeDisponivel
                FROM dbo.Ofertas o WITH (UPDLOCK, ROWLOCK)
                JOIN dbo.Estabelecimentos e ON e.Id = o.EstabelecimentoId
                WHERE o.Id = @OfertaId
                  AND o.Ativa = 1
                  AND e.Ativo = 1
                  AND e.StatusCadastro = N'Aprovado'
                  AND o.RetiradaFim > @Agora;

                IF @Preco IS NULL
                    THROW 50001, N'Oferta indisponível.', 1;
                IF @Quantidade < 1 OR @Quantidade > @Disponivel
                    THROW 50002, N'Quantidade maior que a disponível.', 1;
                IF @TipoEntrega = N'Entrega'
                   AND NOT EXISTS (SELECT 1 FROM dbo.Enderecos WHERE Id = @EnderecoId AND UsuarioId = @ClienteId)
                    THROW 50003, N'Endereço de entrega inválido.', 1;

                UPDATE dbo.Ofertas
                   SET QuantidadeDisponivel = QuantidadeDisponivel - @Quantidade, AtualizadoEm = @Agora
                 WHERE Id = @OfertaId;

                DECLARE @Taxa DECIMAL(10,2) = CASE WHEN @TipoEntrega = N'Entrega' THEN @TaxaEntrega ELSE 0 END;

                INSERT INTO dbo.Pedidos (ClienteId, OfertaId, Quantidade, PrecoUnitario, TaxaEntrega, ValorTotal, TipoEntrega,
                                         Status, CodigoRetirada, CriadoEm,
                                         EntregaCep, EntregaLogradouro, EntregaNumero, EntregaComplemento,
                                         EntregaBairro, EntregaCidade, EntregaUf, EntregaLatitude, EntregaLongitude)
                SELECT @ClienteId, @OfertaId, @Quantidade, @Preco, @Taxa, @Preco * @Quantidade + @Taxa, @TipoEntrega,
                       N'AguardandoPagamento', RIGHT(N'000' + CAST(ABS(CHECKSUM(NEWID())) % 10000 AS NVARCHAR(4)), 4), @Agora,
                       en.Cep, en.Logradouro, en.Numero, en.Complemento, en.Bairro, en.Cidade, en.Uf, en.Latitude, en.Longitude
                FROM (SELECT 1 AS x) um
                LEFT JOIN dbo.Enderecos en ON en.Id = @EnderecoId AND @TipoEntrega = N'Entrega';

                SET @PedidoId = SCOPE_IDENTITY();

                COMMIT TRANSACTION;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                THROW;
            END CATCH;
        END;
        """;

    /// <summary>Chamada pelo webhook do gateway. Idempotente: notificações repetidas não alteram nada.</summary>
    public const string ProcConfirmarPagamento = """
        CREATE OR ALTER PROCEDURE dbo.sp_ConfirmarPagamento
            @Provedor   NVARCHAR(30),
            @IdExterno  NVARCHAR(60),
            @PagoEm     DATETIMEOFFSET
        AS
        BEGIN
            SET NOCOUNT ON;
            SET XACT_ABORT ON;

            BEGIN TRANSACTION;

            DECLARE @PedidoId INT;

            UPDATE dbo.Pagamentos
               SET Status = N'Aprovado', PagoEm = @PagoEm, AtualizadoEm = SYSDATETIMEOFFSET(), @PedidoId = PedidoId
             WHERE Provedor = @Provedor AND IdExterno = @IdExterno AND Status = N'Pendente';

            UPDATE dbo.Pedidos
               SET Status = N'Pendente', AtualizadoEm = SYSDATETIMEOFFSET()
             WHERE Id = @PedidoId AND Status = N'AguardandoPagamento';

            COMMIT TRANSACTION;
        END;
        """;

    /// <summary>Cancela pedidos não pagos no prazo (RN03); o estoque volta pelo trigger.</summary>
    public const string ProcExpirarPedidosNaoPagos = """
        CREATE OR ALTER PROCEDURE dbo.sp_ExpirarPedidosNaoPagos
            @Minutos INT = 15
        AS
        BEGIN
            SET NOCOUNT ON;

            UPDATE dbo.Pedidos
               SET Status = N'Cancelado', AtualizadoEm = SYSDATETIMEOFFSET()
             WHERE Status = N'AguardandoPagamento'
               AND CriadoEm < DATEADD(MINUTE, -@Minutos, SYSDATETIMEOFFSET());

            SELECT @@ROWCOUNT AS PedidosCancelados;
        END;
        """;

    /// <summary>Indicadores de impacto do painel do estabelecimento.</summary>
    public const string ProcIndicadoresImpacto = """
        CREATE OR ALTER PROCEDURE dbo.sp_IndicadoresImpacto
            @EstabelecimentoId INT,
            @Inicio            DATETIMEOFFSET,
            @Fim               DATETIMEOFFSET
        AS
        BEGIN
            SET NOCOUNT ON;

            SELECT COUNT(*)                                                     AS PedidosEntregues,
                   ISNULL(SUM(p.Quantidade), 0)                                 AS UnidadesVendidas,
                   ISNULL(SUM(p.Quantidade * ISNULL(o.PesoEstimadoKg, 0)), 0)   AS KgSalvos,
                   ISNULL(SUM(p.PrecoUnitario * p.Quantidade), 0)               AS Receita,
                   ISNULL(SUM((o.PrecoOriginal - p.PrecoUnitario) * p.Quantidade), 0) AS EconomiaClientes
            FROM dbo.Pedidos p
            JOIN dbo.Ofertas o ON o.Id = p.OfertaId
            WHERE o.EstabelecimentoId = @EstabelecimentoId
              AND p.Status = N'Entregue'
              AND p.CriadoEm >= @Inicio AND p.CriadoEm < @Fim;
        END;
        """;

    /// <summary>LGPD: apaga as posições de entregas concluídas há mais de @Dias dias (RN09).</summary>
    public const string ProcLimparRastreiosAntigos = """
        CREATE OR ALTER PROCEDURE dbo.sp_LimparRastreiosAntigos
            @Dias INT = 30
        AS
        BEGIN
            SET NOCOUNT ON;

            DELETE r
            FROM dbo.RastreiosEntrega r
            JOIN dbo.Pedidos p ON p.Id = r.PedidoId
            WHERE p.Status IN (N'Entregue', N'Cancelado')
              AND p.AtualizadoEm < DATEADD(DAY, -@Dias, SYSDATETIMEOFFSET());

            SELECT @@ROWCOUNT AS RegistrosApagados;
        END;
        """;

    public static readonly string[] Todos =
    [
        TriggerPedidosStatus, TriggerEstabelecimentosDesativacao, TriggerOfertasRemocaoLogica,
        ProcCriarPedido, ProcConfirmarPagamento, ProcExpirarPedidosNaoPagos, ProcIndicadoresImpacto,
        ProcLimparRastreiosAntigos
    ];

    public const string Remover = """
        DROP TRIGGER IF EXISTS dbo.trg_Pedidos_Status;
        DROP TRIGGER IF EXISTS dbo.trg_Estabelecimentos_Desativacao;
        DROP TRIGGER IF EXISTS dbo.trg_Ofertas_RemocaoLogica;
        DROP PROCEDURE IF EXISTS dbo.sp_CriarPedido;
        DROP PROCEDURE IF EXISTS dbo.sp_ConfirmarPagamento;
        DROP PROCEDURE IF EXISTS dbo.sp_ExpirarPedidosNaoPagos;
        DROP PROCEDURE IF EXISTS dbo.sp_IndicadoresImpacto;
        DROP PROCEDURE IF EXISTS dbo.sp_LimparRastreiosAntigos;
        """;
}
