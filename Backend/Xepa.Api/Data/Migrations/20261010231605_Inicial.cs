using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Xepa.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class Inicial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Usuarios",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Nome = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(254)", maxLength: 254, nullable: false),
                    SenhaHash = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Telefone = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    Tipo = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Usuarios", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Enderecos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    Apelido = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Principal = table.Column<bool>(type: "bit", nullable: false),
                    Bairro = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    Cep = table.Column<string>(type: "nchar(8)", fixedLength: true, maxLength: 8, nullable: false),
                    Cidade = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    Complemento = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Latitude = table.Column<double>(type: "float", nullable: true),
                    Logradouro = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Longitude = table.Column<double>(type: "float", nullable: true),
                    Numero = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Uf = table.Column<string>(type: "nchar(2)", fixedLength: true, maxLength: 2, nullable: false),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Enderecos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Enderecos_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Estabelecimentos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    Nome = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Descricao = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Categoria = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Cnpj = table.Column<string>(type: "nchar(14)", fixedLength: true, maxLength: 14, nullable: true),
                    Telefone = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    LogoUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Ativo = table.Column<bool>(type: "bit", nullable: false),
                    Bairro = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    Cep = table.Column<string>(type: "nchar(8)", fixedLength: true, maxLength: 8, nullable: false),
                    Cidade = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    Complemento = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Latitude = table.Column<double>(type: "float", nullable: true),
                    Logradouro = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Longitude = table.Column<double>(type: "float", nullable: true),
                    Numero = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Uf = table.Column<string>(type: "nchar(2)", fixedLength: true, maxLength: 2, nullable: false),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Estabelecimentos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Estabelecimentos_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Favoritos",
                columns: table => new
                {
                    UsuarioId = table.Column<int>(type: "int", nullable: false),
                    EstabelecimentoId = table.Column<int>(type: "int", nullable: false),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Favoritos", x => new { x.UsuarioId, x.EstabelecimentoId });
                    table.ForeignKey(
                        name: "FK_Favoritos_Estabelecimentos_EstabelecimentoId",
                        column: x => x.EstabelecimentoId,
                        principalTable: "Estabelecimentos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Favoritos_Usuarios_UsuarioId",
                        column: x => x.UsuarioId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Ofertas",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    EstabelecimentoId = table.Column<int>(type: "int", nullable: false),
                    Titulo = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Descricao = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    FotoUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    PrecoOriginal = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    Preco = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    QuantidadeDisponivel = table.Column<int>(type: "int", nullable: false),
                    PesoEstimadoKg = table.Column<decimal>(type: "decimal(6,2)", precision: 6, scale: 2, nullable: true),
                    RetiradaInicio = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RetiradaFim = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    Ativa = table.Column<bool>(type: "bit", nullable: false),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Ofertas", x => x.Id);
                    table.CheckConstraint("CK_Ofertas_Preco", "[Preco] >= 0 AND [Preco] <= [PrecoOriginal]");
                    table.CheckConstraint("CK_Ofertas_QuantidadeDisponivel", "[QuantidadeDisponivel] >= 0");
                    table.CheckConstraint("CK_Ofertas_Retirada", "[RetiradaFim] > [RetiradaInicio]");
                    table.ForeignKey(
                        name: "FK_Ofertas_Estabelecimentos_EstabelecimentoId",
                        column: x => x.EstabelecimentoId,
                        principalTable: "Estabelecimentos",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Pedidos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ClienteId = table.Column<int>(type: "int", nullable: false),
                    OfertaId = table.Column<int>(type: "int", nullable: false),
                    Quantidade = table.Column<int>(type: "int", nullable: false),
                    PrecoUnitario = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    TaxaEntrega = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    ValorTotal = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: false),
                    TipoEntrega = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Observacao = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    EntregaBairro = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: true),
                    EntregaCep = table.Column<string>(type: "nchar(8)", fixedLength: true, maxLength: 8, nullable: true),
                    EntregaCidade = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: true),
                    EntregaComplemento = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    EntregaLatitude = table.Column<double>(type: "float", nullable: true),
                    EntregaLogradouro = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: true),
                    EntregaLongitude = table.Column<double>(type: "float", nullable: true),
                    EntregaNumero = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    EntregaUf = table.Column<string>(type: "nchar(2)", fixedLength: true, maxLength: 2, nullable: true),
                    CriadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    AtualizadoEm = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Pedidos", x => x.Id);
                    table.CheckConstraint("CK_Pedidos_EnderecoEntrega", "[TipoEntrega] <> 'Entrega' OR [EntregaLogradouro] IS NOT NULL");
                    table.CheckConstraint("CK_Pedidos_Quantidade", "[Quantidade] > 0");
                    table.ForeignKey(
                        name: "FK_Pedidos_Ofertas_OfertaId",
                        column: x => x.OfertaId,
                        principalTable: "Ofertas",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Pedidos_Usuarios_ClienteId",
                        column: x => x.ClienteId,
                        principalTable: "Usuarios",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Enderecos_UsuarioId",
                table: "Enderecos",
                column: "UsuarioId");

            migrationBuilder.CreateIndex(
                name: "IX_Enderecos_UsuarioId_Principal",
                table: "Enderecos",
                column: "UsuarioId",
                unique: true,
                filter: "[Principal] = 1");

            migrationBuilder.CreateIndex(
                name: "IX_Estabelecimentos_Categoria",
                table: "Estabelecimentos",
                column: "Categoria");

            migrationBuilder.CreateIndex(
                name: "IX_Estabelecimentos_Cnpj",
                table: "Estabelecimentos",
                column: "Cnpj",
                unique: true,
                filter: "[Cnpj] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Estabelecimentos_UsuarioId",
                table: "Estabelecimentos",
                column: "UsuarioId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Favoritos_EstabelecimentoId",
                table: "Favoritos",
                column: "EstabelecimentoId");

            migrationBuilder.CreateIndex(
                name: "IX_Ofertas_EstabelecimentoId",
                table: "Ofertas",
                column: "EstabelecimentoId");

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_ClienteId",
                table: "Pedidos",
                column: "ClienteId");

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_OfertaId",
                table: "Pedidos",
                column: "OfertaId");

            migrationBuilder.CreateIndex(
                name: "IX_Pedidos_Status",
                table: "Pedidos",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_Usuarios_Email",
                table: "Usuarios",
                column: "Email",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Enderecos");

            migrationBuilder.DropTable(
                name: "Favoritos");

            migrationBuilder.DropTable(
                name: "Pedidos");

            migrationBuilder.DropTable(
                name: "Ofertas");

            migrationBuilder.DropTable(
                name: "Estabelecimentos");

            migrationBuilder.DropTable(
                name: "Usuarios");
        }
    }
}
