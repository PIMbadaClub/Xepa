namespace Xepa.Api.Entities;

/// <summary>
/// Base das entidades com chave inteira. As datas são preenchidas pelo XepaDbContext ao salvar.
/// </summary>
public abstract class Entidade
{
    public int Id { get; set; }
    public DateTimeOffset CriadoEm { get; set; }
    public DateTimeOffset? AtualizadoEm { get; set; }
}
