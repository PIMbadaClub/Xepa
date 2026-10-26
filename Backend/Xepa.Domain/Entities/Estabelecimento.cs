namespace Xepa.Domain.Entities;

public class Estabelecimento : Entidade
{
    public int UsuarioId { get; set; }
    public Usuario Usuario { get; set; } = null!;

    public required string Nome { get; set; }
    public string? Descricao { get; set; }
    public CategoriaEstabelecimento Categoria { get; set; }
    public string? Cnpj { get; set; }
    public string? Telefone { get; set; }
    public string? LogoUrl { get; set; }
    public required Endereco Endereco { get; set; }

    /// <summary>Loja nova entra como Pendente e só aparece no app depois de aprovada (RN10).</summary>
    public StatusCadastro StatusCadastro { get; set; } = StatusCadastro.Pendente;

    public bool Ativo { get; set; } = true;

    public List<Oferta> Ofertas { get; set; } = [];
    public List<Entregador> Entregadores { get; set; } = [];

    public bool VisivelNoApp => Ativo && StatusCadastro == StatusCadastro.Aprovado;

    /// <summary>Tira a loja e as ofertas carregadas do ar; no banco, o trigger desativa as demais.</summary>
    public void Desativar()
    {
        Ativo = false;
        foreach (var oferta in Ofertas)
            oferta.Ativa = false;
    }
}
