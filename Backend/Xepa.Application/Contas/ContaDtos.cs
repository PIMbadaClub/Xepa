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

public class RenovarRequest
{
    [Required]
    public required string TokenRenovacao { get; init; }
}

public record SessaoDto(string TokenAcesso, DateTimeOffset AcessoExpiraEm, string TokenRenovacao,
    DateTimeOffset RenovacaoExpiraEm, UsuarioDto Usuario);

public record UsuarioDto(int Id, string Nome, string Email, string? Telefone, TipoUsuario Tipo, int? EstabelecimentoId);
