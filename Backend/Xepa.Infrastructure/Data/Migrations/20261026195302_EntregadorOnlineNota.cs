using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Xepa.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class EntregadorOnlineNota : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Placa",
                table: "Usuarios",
                type: "nvarchar(8)",
                maxLength: 8,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ModeloMoto",
                table: "Usuarios",
                type: "nvarchar(60)",
                maxLength: 60,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "Online",
                table: "Usuarios",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "RaioCorridasKm",
                table: "Usuarios",
                type: "int",
                nullable: false,
                defaultValue: 8);

            migrationBuilder.AddColumn<string>(
                name: "ComentarioEntregador",
                table: "Pedidos",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "EntregadorAvaliadoEm",
                table: "Pedidos",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "NotaEntregador",
                table: "Pedidos",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ModeloMoto",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "Online",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "RaioCorridasKm",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "ComentarioEntregador",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "EntregadorAvaliadoEm",
                table: "Pedidos");

            migrationBuilder.DropColumn(
                name: "NotaEntregador",
                table: "Pedidos");

            migrationBuilder.AlterColumn<string>(
                name: "Placa",
                table: "Usuarios",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(8)",
                oldMaxLength: 8,
                oldNullable: true);
        }
    }
}
