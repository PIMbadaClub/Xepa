using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Xepa.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class Sprint3NotificacoesPerfil : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "NotificacoesLidasAte",
                table: "Usuarios",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FotoUrl",
                table: "Denuncias",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "NotificacoesLidasAte",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "FotoUrl",
                table: "Denuncias");
        }
    }
}
