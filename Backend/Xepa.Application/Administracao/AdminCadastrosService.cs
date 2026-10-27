using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Xepa.Application.Contas;
using Xepa.Application.Indicadores;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Administracao;

public record UsuarioDetalheAdminDto(int Id, string Nome, string Email, string? Telefone, TipoUsuario Tipo, bool Bloqueado,
    DateTimeOffset CriadoEm, bool ContaGoogle, int Pedidos, decimal Gasto, int? LojaId, string? Loja, string? Placa,
    string? ModeloMoto, StatusCadastro? CadastroEntregador, IReadOnlyList<PedidoAdminDto> UltimosPedidos);

public class EditarUsuarioAdminForm
{
    [Required(ErrorMessage = "Informe o nome."), StringLength(120), Display(Name = "Nome")]
    public string Nome { get; set; } = "";

    [Required(ErrorMessage = "Informe o e-mail."), EmailAddress(ErrorMessage = "E-mail inválido."), StringLength(254), Display(Name = "E-mail")]
    public string Email { get; set; } = "";

    [Phone(ErrorMessage = "Telefone inválido."), StringLength(20), Display(Name = "Telefone")]
    public string? Telefone { get; set; }

    [RegularExpression(@"^[A-Za-z]{3}-?\d[A-Za-z\d]\d{2}$", ErrorMessage = "Placa inválida (ex.: ABC1D23)."), Display(Name = "Placa da moto")]
    public string? Placa { get; set; }

    [StringLength(60), Display(Name = "Modelo da moto")]
    public string? ModeloMoto { get; set; }
}

public record LojaDetalheAdminDto(int Id, string Nome, string? Descricao, CategoriaEstabelecimento Categoria, string? Cnpj,
    string? Telefone, Endereco Endereco, StatusCadastro Status, bool Ativa, DateTimeOffset CriadoEm, int ResponsavelId,
    string Responsavel, string Email, int OfertasAtivas, int PedidosEntregues, decimal Vendas, decimal RepasseAberto,
    ReputacaoLojaDto Reputacao);

public class EditarLojaAdminForm
{
    [Required(ErrorMessage = "Informe o nome da loja."), StringLength(120), Display(Name = "Nome da loja")]
    public string Nome { get; set; } = "";

    [StringLength(500), Display(Name = "Descrição")]
    public string? Descricao { get; set; }

    [Display(Name = "Categoria")]
    public CategoriaEstabelecimento Categoria { get; set; }

    [RegularExpression(@"^\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}$", ErrorMessage = "CNPJ inválido."), Display(Name = "CNPJ")]
    public string? Cnpj { get; set; }

    [Phone(ErrorMessage = "Telefone inválido."), StringLength(20), Display(Name = "Telefone")]
    public string? Telefone { get; set; }

    [Required(ErrorMessage = "Informe o CEP."), RegularExpression(@"^\d{5}-?\d{3}$", ErrorMessage = "CEP inválido."), Display(Name = "CEP")]
    public string Cep { get; set; } = "";

    [Required(ErrorMessage = "Informe a rua."), StringLength(150), Display(Name = "Rua")]
    public string Logradouro { get; set; } = "";

    [Required(ErrorMessage = "Informe o número."), StringLength(20), Display(Name = "Número")]
    public string Numero { get; set; } = "";

    [StringLength(60), Display(Name = "Complemento")]
    public string? Complemento { get; set; }

    [Required(ErrorMessage = "Informe o bairro."), StringLength(80), Display(Name = "Bairro")]
    public string Bairro { get; set; } = "";

    [Required(ErrorMessage = "Informe a cidade."), StringLength(80), Display(Name = "Cidade")]
    public string Cidade { get; set; } = "";

    [Required(ErrorMessage = "Informe a UF."), RegularExpression("^[A-Za-z]{2}$", ErrorMessage = "UF com 2 letras."), Display(Name = "UF")]
    public string Uf { get; set; } = "SP";
}

/// <summary>Detalhe e edição de usuários e lojas pela equipe da XEPA.</summary>
public class AdminCadastrosService(IXepaDb db, IServicoMapas mapas, IndicadoresService indicadores)
{
    // ---------- Usuários ----------

    public async Task<UsuarioDetalheAdminDto> ObterUsuarioAsync(int id, CancellationToken ct)
    {
        var u = await db.Usuarios.AsNoTracking().Include(x => x.Estabelecimento).FirstOrDefaultAsync(x => x.Id == id, ct)
                ?? throw new NaoEncontradoException("Usuário não encontrado.");
        var feitos = db.Pedidos.AsNoTracking().Where(p => p.ClienteId == id && p.Status == StatusPedido.Entregue);
        var lojaId = u.Estabelecimento?.Id;
        var ultimos = await AdminPedidosService.Projetar(db.Pedidos.AsNoTracking()
                .Where(p => p.ClienteId == id || p.EntregadorId == id || (lojaId != null && p.Oferta.EstabelecimentoId == lojaId))
                .OrderByDescending(p => p.CriadoEm).Take(10))
            .ToListAsync(ct);

        return new UsuarioDetalheAdminDto(u.Id, u.Nome, u.Email, u.Telefone, u.Tipo, u.Bloqueado, u.CriadoEm, u.GoogleId != null,
            await feitos.CountAsync(ct), await feitos.SumAsync(p => (decimal?)p.ValorTotal, ct) ?? 0,
            u.Estabelecimento?.Id, u.Estabelecimento?.Nome, u.Placa, u.ModeloMoto, u.CadastroEntregador, ultimos);
    }

    public async Task AtualizarUsuarioAsync(int id, EditarUsuarioAdminForm form, CancellationToken ct)
    {
        var u = await db.Usuarios.FirstOrDefaultAsync(x => x.Id == id, ct)
                ?? throw new NaoEncontradoException("Usuário não encontrado.");
        var email = CredenciaisService.NormalizarEmail(form.Email);
        if (email != u.Email && await db.Usuarios.AnyAsync(x => x.Email == email && x.Id != id, ct))
            throw new RegraDeNegocioException("Já existe outra conta com este e-mail.");

        u.Nome = form.Nome.Trim();
        u.Email = email;
        u.Telefone = string.IsNullOrWhiteSpace(form.Telefone) ? null : form.Telefone.Trim();
        if (u.Tipo == TipoUsuario.Entregador)
        {
            if (string.IsNullOrWhiteSpace(form.Placa))
                throw new RegraDeNegocioException("Entregador precisa da placa da moto.");
            u.Placa = form.Placa.Replace("-", "").Trim().ToUpperInvariant();
            u.ModeloMoto = string.IsNullOrWhiteSpace(form.ModeloMoto) ? null : form.ModeloMoto.Trim();
        }
        await db.SaveChangesAsync(ct);
    }

    // ---------- Lojas ----------

    public async Task<LojaDetalheAdminDto> ObterLojaAsync(int id, CancellationToken ct)
    {
        var l = await db.Estabelecimentos.AsNoTracking().Include(e => e.Usuario).FirstOrDefaultAsync(e => e.Id == id, ct)
                ?? throw new NaoEncontradoException("Loja não encontrada.");
        var entregues = db.Pedidos.AsNoTracking().Where(p => p.Oferta.EstabelecimentoId == id && p.Status == StatusPedido.Entregue);

        return new LojaDetalheAdminDto(l.Id, l.Nome, l.Descricao, l.Categoria, l.Cnpj, l.Telefone, l.Endereco, l.StatusCadastro, l.Ativo,
            l.CriadoEm, l.UsuarioId, l.Usuario.Nome, l.Usuario.Email,
            await db.Ofertas.CountAsync(o => o.EstabelecimentoId == id && o.Ativa, ct),
            await entregues.CountAsync(ct),
            await entregues.SumAsync(p => (decimal?)(p.PrecoUnitario * p.Quantidade), ct) ?? 0,
            await db.Repasses.Where(r => r.EstabelecimentoId == id && r.PagoEm == null).SumAsync(r => (decimal?)r.ValorLiquido, ct) ?? 0,
            await indicadores.ReputacaoLojaAsync(id, ct));
    }

    public static EditarLojaAdminForm FormDe(LojaDetalheAdminDto l) => new()
    {
        Nome = l.Nome, Descricao = l.Descricao, Categoria = l.Categoria, Cnpj = l.Cnpj, Telefone = l.Telefone,
        Cep = l.Endereco.Cep.Trim(), Logradouro = l.Endereco.Logradouro, Numero = l.Endereco.Numero, Complemento = l.Endereco.Complemento,
        Bairro = l.Endereco.Bairro, Cidade = l.Endereco.Cidade, Uf = l.Endereco.Uf
    };

    /// <summary>Atualiza os dados da loja; mudou o endereço, localiza de novo no mapa (sem localização a loja some do mapa).</summary>
    public async Task AtualizarLojaAsync(int id, EditarLojaAdminForm form, CancellationToken ct)
    {
        var l = await db.Estabelecimentos.FirstOrDefaultAsync(e => e.Id == id, ct)
                ?? throw new NaoEncontradoException("Loja não encontrada.");

        var novo = new Endereco
        {
            Cep = form.Cep.Replace("-", "").Trim(), Logradouro = form.Logradouro.Trim(), Numero = form.Numero.Trim(),
            Complemento = string.IsNullOrWhiteSpace(form.Complemento) ? null : form.Complemento.Trim(),
            Bairro = form.Bairro.Trim(), Cidade = form.Cidade.Trim(), Uf = form.Uf.Trim().ToUpperInvariant(),
            Latitude = l.Endereco.Latitude, Longitude = l.Endereco.Longitude
        };
        var mudouEndereco = novo with { Latitude = null, Longitude = null } != l.Endereco with { Latitude = null, Longitude = null };
        if (mudouEndereco)
        {
            var ponto = await mapas.GeocodificarAsync(novo, ct)
                        ?? throw new RegraDeNegocioException("Não foi possível localizar o novo endereço no mapa. Confira o CEP e o número.");
            novo = novo with { Latitude = ponto.Latitude, Longitude = ponto.Longitude };
        }

        l.Nome = form.Nome.Trim();
        l.Descricao = string.IsNullOrWhiteSpace(form.Descricao) ? null : form.Descricao.Trim();
        l.Categoria = form.Categoria;
        l.Cnpj = string.IsNullOrWhiteSpace(form.Cnpj) ? null : form.Cnpj.Trim();
        l.Telefone = string.IsNullOrWhiteSpace(form.Telefone) ? null : form.Telefone.Trim();
        l.Endereco = novo;
        await db.SaveChangesAsync(ct);
    }
}
