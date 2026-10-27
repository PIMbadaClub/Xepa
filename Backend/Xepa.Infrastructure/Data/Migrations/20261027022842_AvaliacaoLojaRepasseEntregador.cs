using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Xepa.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class AvaliacaoLojaRepasseEntregador : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CadastroEntregador",
                table: "Usuarios",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ComentarioLoja",
                table: "Pedidos",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "LojaAvaliadaEm",
                table: "Pedidos",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "NotaLoja",
                table: "Pedidos",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RepasseEntregadorId",
                table: "Pedidos",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "RepassesEntregadores",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    EntregadorId = table.Column<int>(type: "int", nullable: false),
                    QuantidadeCorridas = table.Column<int>(type: "int", nullable: false),
                    KmTotal = table.Column<double>(type: "float", nullable: false),
                    Valor = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    PagoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RepassesEntregadores", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RepassesEntregadores_Usuarios_EntregadorId",
                        column: x => x.EntregadorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_RepasseEntregadorId",
                table: "Pedidos",
                column: "RepasseEntregadorId");

            migrationBuilder.CreateIndex(
                name: "IX_RepassesEntregadores_EntregadorId_CriadoEm",
                table: "RepassesEntregadores",
                columns: new[] { "EntregadorId", "CriadoEm" });

            migrationBuilder.AddForeignKey(
                name: "FK_Pedidos_RepassesEntregadores_RepasseEntregadorId",
                table: "Pedidos",
                column: "RepasseEntregadorId",
                principalTable: "RepassesEntregadores",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            // Entregadores que já existiam continuam trabalhando; os novos passam pela aprovação.
            migrationBuilder.Sql("UPDATE Usuarios SET CadastroEntregador = 'Aprovado' WHERE Tipo = 'Entregador'");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Pedidos_RepassesEntregadores_RepasseEntregadorId",
                table: "Pedidos");

            migrationBuilder.DropTable(
                name: "RepassesEntregadores");

            migrationBuilder.DropIndex(
                name: "IX_Pedidos_RepasseEntregadorId",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "CadastroEntregador",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "ComentarioLoja",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "LojaAvaliadaEm",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "NotaLoja",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "RepasseEntregadorId",
                table: "Pedidos");
        }
    }
}
