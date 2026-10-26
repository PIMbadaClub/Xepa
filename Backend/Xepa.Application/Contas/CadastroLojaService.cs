using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Contas;

/// <summary>Formulário "Cadastre sua loja" do portal.</summary>
public class CadastroLojaForm
{
    [Required(ErrorMessage = "Informe o nome da loja."), StringLength(120), Display(Name = "Nome da loja")]
    public string NomeLoja { get; set; } = "";

    [Display(Name = "Categoria")]
    public CategoriaEstabelecimento Categoria { get; set; } = CategoriaEstabelecimento.Padaria;

    [Required(ErrorMessage = "Informe o CNPJ."), RegularExpression(@"^\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}$", ErrorMessage = "CNPJ inválido."), Display(Name = "CNPJ")]
    public string Cnpj { get; set; } = "";

    [Required(ErrorMessage = "Informe o telefone."), Phone, Display(Name = "Telefone")]
    public string Telefone { get; set; } = "";

    [Required(ErrorMessage = "Informe seu nome."), StringLength(120), Display(Name = "Seu nome (responsável)")]
    public string Responsavel { get; set; } = "";

    [Required(ErrorMessage = "Informe o e-mail."), EmailAddress(ErrorMessage = "E-mail inválido."), Display(Name = "E-mail de acesso")]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "Crie uma senha."), StringLength(100, MinimumLength = 8, ErrorMessage = "Use ao menos 8 caracteres."), DataType(DataType.Password), Display(Name = "Senha")]
    public string Senha { get; set; } = "";

    [Required(ErrorMessage = "Informe o CEP."), RegularExpression(@"^\d{5}-?\d{3}$", ErrorMessage = "CEP inválido."), Display(Name = "CEP")]
    public string Cep { get; set; } = "";

    [Required(ErrorMessage = "Informe a rua."), StringLength(150), Display(Name = "Rua")]
    public string Logradouro { get; set; } = "";

    [Required(ErrorMessage = "Informe o número."), StringLength(20), Display(Name = "Número")]
    public string Numero { get; set; } = "";

    [Required(ErrorMessage = "Informe o bairro."), StringLength(80), Display(Name = "Bairro")]
    public string Bairro { get; set; } = "";

    [Required(ErrorMessage = "Informe a cidade."), StringLength(80), Display(Name = "Cidade")]
    public string Cidade { get; set; } = "São Paulo";

    [Required(ErrorMessage = "Informe a UF."), RegularExpression("^[A-Za-z]{2}$", ErrorMessage = "UF com 2 letras."), Display(Name = "UF")]
    public string Uf { get; set; } = "SP";
}

/// <summary>Cadastro de estabelecimento pelo portal. A loja entra pendente e só aparece no app depois de aprovada (RN10).</summary>
public class CadastroLojaService(IXepaDb db, IHasherSenha hasher, IServicoMapas mapas)
{
    public async Task<Usuario> RegistrarAsync(CadastroLojaForm form, CancellationToken ct)
    {
        var email = CredenciaisService.NormalizarEmail(form.Email);
        if (await db.Usuarios.AnyAsync(u => u.Email == email, ct))
            throw new RegraDeNegocioException("Já existe uma conta com este e-mail.");

        var cnpj = SoDigitos(form.Cnpj);
        if (!CnpjValido(cnpj))
            throw new RegraDeNegocioException("CNPJ inválido.");
        if (await db.Estabelecimentos.AnyAsync(e => e.Cnpj == cnpj, ct))
            throw new RegraDeNegocioException("Já existe uma loja com este CNPJ.");

        var endereco = new Endereco
        {
            Cep = SoDigitos(form.Cep),
            Logradouro = form.Logradouro.Trim(),
            Numero = form.Numero.Trim(),
            Bairro = form.Bairro.Trim(),
            Cidade = form.Cidade.Trim(),
            Uf = form.Uf.Trim().ToUpperInvariant()
        };
        // Sem coordenadas a loja ainda é cadastrada; o administrador vê o aviso na aprovação.
        if (await mapas.GeocodificarAsync(endereco, ct) is { } ponto)
            endereco = endereco with { Latitude = ponto.Latitude, Longitude = ponto.Longitude };

        var usuario = new Usuario
        {
            Nome = form.Responsavel.Trim(),
            Email = email,
            Telefone = form.Telefone.Trim(),
            Tipo = TipoUsuario.Estabelecimento,
            SenhaHash = ""
        };
        usuario.SenhaHash = hasher.Gerar(usuario, form.Senha);
        usuario.Estabelecimento = new Estabelecimento
        {
            Nome = form.NomeLoja.Trim(),
            Categoria = form.Categoria,
            Cnpj = cnpj,
            Telefone = form.Telefone.Trim(),
            Endereco = endereco,
            StatusCadastro = StatusCadastro.Pendente,
            Usuario = usuario
        };

        db.Usuarios.Add(usuario);
        await db.SaveChangesAsync(ct);
        return usuario;
    }

    private static string SoDigitos(string valor) => new(valor.Where(char.IsDigit).ToArray());

    /// <summary>Confere os dois dígitos verificadores do CNPJ.</summary>
    public static bool CnpjValido(string cnpj)
    {
        if (cnpj.Length != 14 || cnpj.Distinct().Count() == 1)
            return false;

        static int Digito(string baseNumeros, int[] pesos)
        {
            var soma = baseNumeros.Select((c, i) => (c - '0') * pesos[i]).Sum();
            var resto = soma % 11;
            return resto < 2 ? 0 : 11 - resto;
        }

        int[] pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
        int[] pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
        var d1 = Digito(cnpj[..12], pesos1);
        var d2 = Digito(cnpj[..12] + d1, pesos2);
        return cnpj[12] - '0' == d1 && cnpj[13] - '0' == d2;
    }
}
