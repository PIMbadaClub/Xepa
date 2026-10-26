using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Xepa.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class Sprint3AdminImpacto : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "Bloqueado",
                table: "Usuarios",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "RepasseId",
                table: "Pedidos",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Denuncias",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PedidoId = table.Column<int>(type: "int", nullable: false),
                    AutorId = table.Column<int>(type: "int", nullable: false),
                    EstabelecimentoId = table.Column<int>(type: "int", nullable: false),
                    Motivo = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Descricao = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Resposta = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    TratadaEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    TratadaPorId = table.Column<int>(type: "int", nullable: true),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Denuncias", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Denuncias_Estabelecimentos_EstabelecimentoId",
                        column: x => x.EstabelecimentoId,
                        principalTable: "Estabelecimentos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Denuncias_Pedidos_PedidoId",
                        column: x => x.PedidoId,
                        principalTable: "Pedidos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Denuncias_Usuarios_AutorId",
                        column: x => x.AutorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Denuncias_Usuarios_TratadaPorId",
                        column: x => x.TratadaPorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Repasses",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    EstabelecimentoId = table.Column<int>(type: "int", nullable: false),
                    QuantidadePedidos = table.Column<int>(type: "int", nullable: false),
                    ValorVendas = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    Comissao = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    TaxasEntrega = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    ValorLiquido = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    PagoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Repasses", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Repasses_Estabelecimentos_EstabelecimentoId",
                        column: x => x.EstabelecimentoId,
                        principalTable: "Estabelecimentos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_RepasseId",
                table: "Pedidos",
                column: "RepasseId");

            migrationBuilder.CreateIndex(
                name: "IX_Denuncias_AutorId",
                table: "Denuncias",
                column: "AutorId");

            migrationBuilder.CreateIndex(
                name: "IX_Denuncias_EstabelecimentoId",
                table: "Denuncias",
                column: "EstabelecimentoId");

            migrationBuilder.CreateIndex(
                name: "IX_Denuncias_PedidoId",
                table: "Denuncias",
                column: "PedidoId",
                unique: true,
                filter: "[Status] = 'Aberta'");

            migrationBuilder.CreateIndex(
                name: "IX_Denuncias_Status_CriadoEm",
                table: "Denuncias",
                columns: new[] { "Status", "CriadoEm" });

            migrationBuilder.CreateIndex(
                name: "IX_Denuncias_TratadaPorId",
                table: "Denuncias",
                column: "TratadaPorId");

            migrationBuilder.CreateIndex(
                name: "IX_Repasses_EstabelecimentoId_CriadoEm",
                table: "Repasses",
                columns: new[] { "EstabelecimentoId", "CriadoEm" });

            migrationBuilder.AddForeignKey(
                name: "FK_Pedidos_Repasses_RepasseId",
                table: "Pedidos",
                column: "RepasseId",
                principalTable: "Repasses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Pedidos_Repasses_RepasseId",
                table: "Pedidos");

            migrationBuilder.DropTable(
                name: "Denuncias");

            migrationBuilder.DropTable(
                name: "Repasses");

            migrationBuilder.DropIndex(
                name: "IX_Pedidos_RepasseId",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "Bloqueado",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "RepasseId",
                table: "Pedidos");
        }
    }
}
