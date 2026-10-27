using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Xepa.Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class SuportePushLgpd : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "ExcluidaEm",
                table: "Usuarios",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "TermosAceitosEm",
                table: "Usuarios",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ConversasSuporte",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    UltimaMensagemEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    NaoLidasUsuario = table.Column<int>(type: "int", nullable: false),
                    NaoLidasSuporte = table.Column<int>(type: "int", nullable: false),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ConversasSuporte", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ConversasSuporte_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "DispositivosPush",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    Token = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    Plataforma = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DispositivosPush", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DispositivosPush_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "MensagensSuporte",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ConversaId = table.Column<int>(type: "int", nullable: false),
                    AutorId = table.Column<int>(type: "int", nullable: true),
                    DoSuporte = table.Column<bool>(type: "bit", nullable: false),
                    Automatica = table.Column<bool>(type: "bit", nullable: false),
                    Texto = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    PedidoId = table.Column<int>(type: "int", nullable: true),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MensagensSuporte", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MensagensSuporte_ConversasSuporte_ConversaId",
                        column: x => x.ConversaId,
                        principalTable: "ConversasSuporte",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_MensagensSuporte_Pedidos_PedidoId",
                        column: x => x.PedidoId,
                        principalTable: "Pedidos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MensagensSuporte_Usuarios_AutorId",
                        column: x => x.AutorId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ConversasSuporte_Status_UltimaMensagemEm",
                table: "ConversasSuporte",
                columns: new[] { "Status", "UltimaMensagemEm" });

            migrationBuilder.CreateIndex(
                name: "IX_ConversasSuporte_UsuarioId",
                table: "ConversasSuporte",
                column: "UsuarioId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DispositivosPush_Token",
                table: "DispositivosPush",
                column: "Token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DispositivosPush_UsuarioId",
                table: "DispositivosPush",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_MensagensSuporte_AutorId",
                table: "MensagensSuporte",
                column: "AutorId");

            migrationBuilder.CreateIndex(
                name: "IX_MensagensSuporte_ConversaId_Id",
                table: "MensagensSuporte",
                columns: new[] { "ConversaId", "Id" });

            migrationBuilder.CreateIndex(
                name: "IX_MensagensSuporte_PedidoId",
                table: "MensagensSuporte",
                column: "PedidoId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DispositivosPush");

            migrationBuilder.DropTable(
                name: "MensagensSuporte");

            migrationBuilder.DropTable(
                name: "ConversasSuporte");

            migrationBuilder.DropColumn(
                name: "ExcluidaEm",
                table: "Usuarios");

            migrationBuilder.DropColumn(
                name: "TermosAceitosEm",
                table: "Usuarios");
        }
    }
}
