using System.ComponentModel.DataAnnotations;
using Xepa.Domain.Entities;

namespace Xepa.Application.Contas;

/// <summary>Cadastro pelo app; sempre cria um cliente.</summary>
public class RegistrarRequest
{
    [Required, MaxLength(120)]
    public required string Nome { get; init; }

    [Required, EmailAddress, MaxLength(254)]
    public required string Email { get; init; }

    [Required, MinLength(8), MaxLength(100)]
    public required string Senha { get; init; }

    [Phone, MaxLength(20)]
    public string? Telefone { get; init; }
}

public class LoginRequest
{
    [Required, EmailAddress]
    public required string Email { get; init; }

    [Required]
    public required string Senha { get; init; }
}

public class AtualizarPerfilRequest
{
    [Required(ErrorMessage = "Informe seu nome."), MaxLength(120)]
    public required string Nome { get; init; }

    [Phone(ErrorMessage = "Telefone inválido."), MaxLength(20)]
    public string? Telefone { get; init; }
}

public class AlterarSenhaRequest
{
    [Required(ErrorMessage = "Informe a senha atual.")]
    public required string SenhaAtual { get; init; }

    [Required, MinLength(8, ErrorMessage = "A nova senha precisa de ao menos 8 caracteres."), MaxLength(100)]
    public required string NovaSenha { get; init; }
}

public class RenovarRequest
{
    [Required]
    public required string TokenRenovacao { get; init; }
}

public record SessaoDto(string TokenAcesso, DateTimeOffset AcessoExpiraEm, string TokenRenovacao,
    DateTimeOffset RenovacaoExpiraEm, UsuarioDto Usuario);

public record UsuarioDto(int Id, string Nome, string Email, string? Telefone, TipoUsuario Tipo, int? EstabelecimentoId);
