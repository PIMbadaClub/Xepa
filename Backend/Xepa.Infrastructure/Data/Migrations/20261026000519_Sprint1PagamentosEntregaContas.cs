using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Xepa.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class Sprint1PagamentosEntregaContas : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_Ofertas_Preco",
                table: "Ofertas");

            migrationBuilder.AddColumn<string>(
                name: "CodigoRetirada",
                table: "Pedidos",
                type: "nchar(4)",
                fixedLength: true,
                maxLength: 4,
                nullable: false,
                defaultValue: "0000");

            migrationBuilder.AddColumn<int>(
                name: "EntregadorId",
                table: "Pedidos",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Tipo",
                table: "Ofertas",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Prato");

            migrationBuilder.AddColumn<string>(
                name: "StatusCadastro",
                table: "Estabelecimentos",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Pendente");

            migrationBuilder.CreateTable(
                name: "Entregadores",
                columns: table => new
                {
                    EstabelecimentoId = table.Column<int>(type: "int", nullable: false),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    Ativo = table.Column<bool>(type: "bit", nullable: false),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Entregadores", x => new { x.EstabelecimentoId, x.UsuarioId });
                    table.ForeignKey(
                        name: "FK_Entregadores_Estabelecimentos_EstabelecimentoId",
                        column: x => x.EstabelecimentoId,
                        principalTable: "Estabelecimentos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Entregadores_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Pagamentos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PedidoId = table.Column<int>(type: "int", nullable: false),
                    Provedor = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    IdExterno = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Metodo = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Valor = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    QrCodePix = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    PagoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Pagamentos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Pagamentos_Pedidos_PedidoId",
                        column: x => x.PedidoId,
                        principalTable: "Pedidos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PedidosHistoricoStatus",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PedidoId = table.Column<int>(type: "int", nullable: false),
                    StatusAnterior = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    StatusNovo = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    AlteradoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PedidosHistoricoStatus", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PedidosHistoricoStatus_Pedidos_PedidoId",
                        column: x => x.PedidoId,
                        principalTable: "Pedidos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RastreiosEntrega",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PedidoId = table.Column<int>(type: "int", nullable: false),
                    Latitude = table.Column<double>(type: "float", nullable: false),
                    Longitude = table.Column<double>(type: "float", nullable: false),
                    RegistradoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RastreiosEntrega", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RastreiosEntrega_Pedidos_PedidoId",
                        column: x => x.PedidoId,
                        principalTable: "Pedidos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "TokensRenovacao",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    TokenHash = table.Column<string>(type: "nchar(64)", fixedLength: true, maxLength: 64, nullable: false),
                    ExpiraEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RevogadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TokensRenovacao", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TokensRenovacao_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_EntregadorId",
                table: "Pedidos",
                column: "EntregadorId");

            migrationBuilder.CreateIndex(
                name: "IX_Ofertas_Listagem",
                table: "Ofertas",
                columns: new[] { "Ativa", "RetiradaFim" })
                .Annotation("SqlServer:Include", new[] { "EstabelecimentoId", "QuantidadeDisponivel", "Preco", "PrecoOriginal" });

            migrationBuilder.AddCheckConstraint(
                name: "CK_Ofertas_Preco",
                table: "Ofertas",
                sql: "[Preco] > 0 AND [Preco] < [PrecoOriginal]");

            migrationBuilder.CreateIndex(
                name: "IX_Entregadores_UsuarioId",
                table: "Entregadores",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_Pagamentos_PedidoId",
                table: "Pagamentos",
                column: "PedidoId");

            migrationBuilder.CreateIndex(
                name: "IX_Pagamentos_Provedor_IdExterno",
                table: "Pagamentos",
                columns: new[] { "Provedor", "IdExterno" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PedidosHistoricoStatus_PedidoId",
                table: "PedidosHistoricoStatus",
                column: "PedidoId");

            migrationBuilder.CreateIndex(
                name: "IX_RastreiosEntrega_PedidoId_RegistradoEm",
                table: "RastreiosEntrega",
                columns: new[] { "PedidoId", "RegistradoEm" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "IX_TokensRenovacao_TokenHash",
                table: "TokensRenovacao",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TokensRenovacao_UsuarioId",
                table: "TokensRenovacao",
                column: "UsuarioId");

            migrationBuilder.AddForeignKey(
                name: "FK_Pedidos_Usuarios_EntregadorId",
                table: "Pedidos",
                column: "EntregadorId",
                principalTable: "Usuarios",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            // Lojas que já existiam antes do fluxo de aprovação continuam visíveis no app.
            migrationBuilder.Sql("UPDATE dbo.Estabelecimentos SET StatusCadastro = N'Aprovado';");

            foreach (var sql in Sprint1Sql.Todos)
                migrationBuilder.Sql(sql);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(Sprint1Sql.Remover);

            migrationBuilder.DropForeignKey(
                name: "FK_Pedidos_Usuarios_EntregadorId",
                table: "Pedidos");

            migrationBuilder.DropTable(
                name: "Entregadores");

            migrationBuilder.DropTable(
                name: "Pagamentos");

            migrationBuilder.DropTable(
                name: "PedidosHistoricoStatus");

            migrationBuilder.DropTable(
                name: "RastreiosEntrega");

            migrationBuilder.DropTable(
                name: "TokensRenovacao");

            migrationBuilder.DropIndex(
                name: "IX_Pedidos_EntregadorId",
                table: "Pedidos");

            migrationBuilder.DropIndex(
                name: "IX_Ofertas_Listagem",
                table: "Ofertas");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Ofertas_Preco",
                table: "Ofertas");

            migrationBuilder.DropColumn(
                name: "CodigoRetirada",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "EntregadorId",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "Tipo",
                table: "Ofertas");

            migrationBuilder.DropColumn(
                name: "StatusCadastro",
                table: "Estabelecimentos");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Ofertas_Preco",
                table: "Ofertas",
                sql: "[Preco] >= 0 AND [Preco] <= [PrecoOriginal]");
        }
    }
}
