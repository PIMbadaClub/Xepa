namespace Xepa.Api.Entities;

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
    public bool Ativo { get; set; } = true;

    public List<Oferta> Ofertas { get; set; } = [];
}
