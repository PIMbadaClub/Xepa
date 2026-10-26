namespace Xepa.Domain.Entities;

/// <summary>Situação do cadastro do estabelecimento; só lojas aprovadas aparecem no app (RN10).</summary>
public enum StatusCadastro
{
    Pendente,
    Aprovado,
    Rejeitado
}
