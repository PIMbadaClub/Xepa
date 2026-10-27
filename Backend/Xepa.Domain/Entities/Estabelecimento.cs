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

    /// <summary>A própria loja fechou temporariamente (férias, reforma): as ofertas somem do app até ela reabrir.</summary>
    public bool Pausada { get; set; }

    public List<Oferta> Ofertas { get; set; } = [];
    public List<Entregador> Entregadores { get; set; } = [];

    /// <summary>Horário de funcionamento por dia da semana (um intervalo por dia; dia sem registro = fechada).</summary>
    public List<HorarioFuncionamento> Horarios { get; set; } = [];

    public bool VisivelNoApp => Ativo && !Pausada && StatusCadastro == StatusCadastro.Aprovado;

    /// <summary>Troca o horário da semana inteira. Cada dia aparece no máximo uma vez e fecha depois de abrir.</summary>
    public void DefinirHorarios(IEnumerable<(DayOfWeek Dia, TimeOnly Abre, TimeOnly Fecha)> horarios)
    {
        var lista = horarios.ToList();
        if (lista.GroupBy(h => h.Dia).Any(g => g.Count() > 1))
            throw new RegraDeNegocioException("Cada dia da semana tem um horário só.");
        var invalido = lista.FirstOrDefault(h => h.Fecha <= h.Abre);
        if (invalido != default)
            throw new RegraDeNegocioException($"Na {Funcionamento.NomeDia(invalido.Dia)}, o horário de fechar precisa ser depois do de abrir.");

        Horarios.RemoveAll(h => true);
        foreach (var (dia, abre, fecha) in lista.OrderBy(h => h.Dia))
            Horarios.Add(new HorarioFuncionamento { EstabelecimentoId = Id, DiaSemana = dia, Abre = abre, Fecha = fecha });
    }

    /// <summary>Tira a loja e as ofertas carregadas do ar; no banco, o trigger desativa as demais.</summary>
    public void Desativar()
    {
        Ativo = false;
        foreach (var oferta in Ofertas)
            oferta.Ativa = false;
    }
}
