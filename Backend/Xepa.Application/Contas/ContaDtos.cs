using System.ComponentModel.DataAnnotations;
using Xepa.Domain.Entities;

namespace Xepa.Application.Contas;

/// <summary>Cadastro pelo app: cliente ou entregador parceiro (lojas se cadastram pelo portal).</summary>
public class RegistrarRequest : IValidatableObject
{
    /// <summary>Cliente (padrão) ou Entregador.</summary>
    public TipoUsuario Tipo { get; init; } = TipoUsuario.Cliente;

    /// <summary>Placa da moto; obrigatória para entregador. Aceita o padrão antigo (ABC1234) e o Mercosul (ABC1D23).</summary>
    [RegularExpression(@"^[A-Za-z]{3}-?\d[A-Za-z\d]\d{2}$", ErrorMessage = "Placa inválida.")]
    public string? Placa { get; init; }

    [Required, MaxLength(120)]
    public required string Nome { get; init; }

    [Required, EmailAddress, MaxLength(254)]
    public required string Email { get; init; }

    [Required, MinLength(8), MaxLength(100)]
    public required string Senha { get; init; }

    [Phone, MaxLength(20)]
    public string? Telefone { get; init; }

    /// <summary>Aceite dos termos de uso e da política de privacidade (LGPD); sem ele a conta não é criada.</summary>
    public bool AceitouTermos { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Tipo is not (TipoUsuario.Cliente or TipoUsuario.Entregador))
            yield return new ValidationResult("Pelo app dá para criar conta de cliente ou de entregador.", [nameof(Tipo)]);
        if (!AceitouTermos)
            yield return new ValidationResult("Para criar a conta, aceite os termos de uso e a política de privacidade.", [nameof(AceitouTermos)]);
        if (Tipo == TipoUsuario.Entregador && string.IsNullOrWhiteSpace(Placa))
            yield return new ValidationResult("Informe a placa da moto.", [nameof(Placa)]);
        if (Tipo == TipoUsuario.Entregador && string.IsNullOrWhiteSpace(Telefone))
            yield return new ValidationResult("Informe o celular: a loja e o cliente precisam falar com você.", [nameof(Telefone)]);
    }
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

/// <summary>Conta confirmada pelo Google: identificador fixo, e-mail verificado e nome.</summary>
public record ContaGoogle(string Id, string Email, string Nome);

public record UsuarioDto(int Id, string Nome, string Email, string? Telefone, TipoUsuario Tipo, int? EstabelecimentoId);
