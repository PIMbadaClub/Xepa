using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Xepa.Domain.Entities;

namespace Xepa.Infrastructure.Data;

/// <summary>
/// Dados de demonstração para desenvolvimento: as mesmas ofertas do protótipo do app.
/// Rodam no "dotnet ef database update" (UseSeeding do EF) e só quando o banco ainda não tem usuários.
/// </summary>
public static class DadosIniciais
{
    /// <summary>Senha de todos os usuários de demonstração.</summary>
    public const string SenhaDemo = "Xepa@2026";

    private static readonly TimeZoneInfo FusoSaoPaulo = TimeZoneInfo.FindSystemTimeZoneById("America/Sao_Paulo");

    public static void Popular(DbContext contexto, bool _) =>
        PopularAsync(contexto, _, CancellationToken.None).GetAwaiter().GetResult();

    public static async Task PopularAsync(DbContext contexto, bool _, CancellationToken ct)
    {
        var db = (XepaDbContext)contexto;
        if (await db.Usuarios.AnyAsync(ct))
            return;

        // Coordenadas em volta da Av. Paulista (-23.5614, -46.6559), a 0,4 / 0,9 / 1,2 / 1,6 km dela.
        var padaria = NovoEstabelecimento("Padaria Pão Dourado", CategoriaEstabelecimento.Padaria, "padaria@xepa.test",
            "Rua das Palmeiras", "120", "Bela Vista", -23.5578, -46.6559);
        var cantina = NovoEstabelecimento("Cantina da Nona", CategoriaEstabelecimento.Restaurante, "cantina@xepa.test",
            "Rua do Comércio", "45", "Consolação", -23.5614, -46.6471);
        var barraca = NovoEstabelecimento("Barraca do Seu Zé", CategoriaEstabelecimento.Feira, "feira@xepa.test",
            "Praça da Feira", "s/n", "Paraíso", -23.5722, -46.6559);
        var mercadinho = NovoEstabelecimento("Mercadinho Bom Preço", CategoriaEstabelecimento.Mercado, "mercado@xepa.test",
            "Avenida Central", "800", "Jardins", -23.5614, -46.6716);

        var cliente = NovoUsuario("Cliente Demo", "cliente@xepa.test", TipoUsuario.Cliente);
        cliente.Enderecos.Add(new EnderecoUsuario
        {
            Apelido = "Casa",
            Principal = true,
            Endereco = EnderecoSp("Rua das Flores", "100", "Bela Vista", -23.5614, -46.6559)
        });

        var admin = NovoUsuario("Administrador XEPA", "admin@xepa.test", TipoUsuario.Administrador);
        var entregador = NovoUsuario("Carlos Entregador", "entregador@xepa.test", TipoUsuario.Entregador);
        padaria.Entregadores.Add(new Entregador { Usuario = entregador });

        // Fotos de banco de imagens (Unsplash) só para a demonstração; as lojas reais enviam as suas pelo portal.
        padaria.LogoUrl = Foto("1517433670267-08bbd4be890f", 160);
        cantina.LogoUrl = Foto("1565299624946-b28f40a0ae38", 160);
        barraca.LogoUrl = Foto("1540420773420-3366772f4999", 160);
        mercadinho.LogoUrl = Foto("1542838132-92c53300491e", 160);

        db.Usuarios.AddRange(cliente, admin, entregador);
        db.Estabelecimentos.AddRange(padaria, cantina, barraca, mercadinho);
        db.Ofertas.AddRange(
            NovaOferta(padaria, TipoOferta.SacolaSurpresa, "Sacola surpresa",
                "Pães do dia, bolos, salgados e doces que não foram vendidos. O conteúdo muda a cada dia.",
                precoOriginal: 36m, preco: 12.90m, quantidade: 3, pesoKg: 1.5m, horaInicio: 18, horaFim: 20,
                foto: "1509440159596-0249088772ff"),
            NovaOferta(cantina, TipoOferta.Prato, "Marmita do dia",
                "Pratos preparados no dia, como massas, carnes e acompanhamentos, embalados para viagem.",
                precoOriginal: 42m, preco: 15.90m, quantidade: 1, pesoKg: 1.2m, horaInicio: 21, horaFim: 22,
                foto: "1621996346565-e3dbc646d9a9"),
            NovaOferta(barraca, TipoOferta.SacolaSurpresa, "Caixote de hortifrúti",
                "Frutas, verduras e legumes da xepa do fim da feira, ainda frescos e bons para consumo.",
                precoOriginal: 30m, preco: 9.90m, quantidade: 5, pesoKg: 3.0m, horaInicio: 12, horaFim: 13,
                foto: "1488459716781-31db52582fe9"),
            NovaOferta(mercadinho, TipoOferta.SacolaSurpresa, "Kit mercado",
                "Frios, laticínios e outros itens próximos da data de validade, todos dentro do prazo.",
                precoOriginal: 45m, preco: 17.90m, quantidade: 2, pesoKg: 2.0m, horaInicio: 19, horaFim: 21,
                foto: "1542838132-92c53300491e"));

        await db.SaveChangesAsync(ct);
    }

    private static Usuario NovoUsuario(string nome, string email, TipoUsuario tipo)
    {
        var usuario = new Usuario { Nome = nome, Email = email, Tipo = tipo, SenhaHash = "" };
        usuario.SenhaHash = new PasswordHasher<Usuario>().HashPassword(usuario, SenhaDemo);
        return usuario;
    }

    private static Estabelecimento NovoEstabelecimento(string nome, CategoriaEstabelecimento categoria, string email,
        string logradouro, string numero, string bairro, double latitude, double longitude) => new()
    {
        Nome = nome,
        Categoria = categoria,
        StatusCadastro = StatusCadastro.Aprovado,
        Usuario = NovoUsuario(nome, email, TipoUsuario.Estabelecimento),
        Endereco = EnderecoSp(logradouro, numero, bairro, latitude, longitude)
    };

    private static Endereco EnderecoSp(string logradouro, string numero, string bairro, double latitude, double longitude) => new()
    {
        Cep = "01310000",
        Logradouro = logradouro,
        Numero = numero,
        Bairro = bairro,
        Cidade = "São Paulo",
        Uf = "SP",
        Latitude = latitude,
        Longitude = longitude
    };

    private static Oferta NovaOferta(Estabelecimento estabelecimento, TipoOferta tipo, string titulo, string descricao,
        decimal precoOriginal, decimal preco, int quantidade, decimal pesoKg, int horaInicio, int horaFim, string foto)
    {
        // Janela de retirada de hoje; se ela já passou, a de amanhã, para a oferta aparecer na listagem.
        var agora = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, FusoSaoPaulo);
        var dia = agora.Hour >= horaFim ? agora.Date.AddDays(1) : agora.Date;

        return new Oferta
        {
            Estabelecimento = estabelecimento,
            Tipo = tipo,
            Titulo = titulo,
            Descricao = descricao,
            PrecoOriginal = precoOriginal,
            Preco = preco,
            QuantidadeDisponivel = quantidade,
            PesoEstimadoKg = pesoKg,
            FotoUrl = Foto(foto, 800),
            RetiradaInicio = EmSaoPaulo(dia.AddHours(horaInicio)),
            RetiradaFim = EmSaoPaulo(dia.AddHours(horaFim))
        };
    }

    private static string Foto(string id, int largura) =>
        $"https://images.unsplash.com/photo-{id}?w={largura}&q=75&auto=format&fit=crop";

    private static DateTimeOffset EmSaoPaulo(DateTime horaLocal) =>
        new DateTimeOffset(horaLocal, FusoSaoPaulo.GetUtcOffset(horaLocal)).ToUniversalTime();
}
