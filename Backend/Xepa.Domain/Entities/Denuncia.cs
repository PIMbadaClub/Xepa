namespace Xepa.Domain.Entities;

public enum MotivoDenuncia
{
    ComidaImpropria,
    PedidoNaoEntregue,
    DiferenteDoAnunciado,
    MauAtendimento,
    Discriminacao,
    Outro
}

public enum StatusDenuncia
{
    Aberta,
    Procedente,
    Improcedente
}

/// <summary>Denúncia feita pelo cliente sobre um pedido; tratada pela equipe da XEPA no portal administrativo.</summary>
public class Denuncia : Entidade
{
    public int PedidoId { get; set; }
    public Pedido Pedido { get; set; } = null!;

    public int AutorId { get; set; }
    public Usuario Autor { get; set; } = null!;

    public int EstabelecimentoId { get; set; }
    public Estabelecimento Estabelecimento { get; set; } = null!;

    public MotivoDenuncia Motivo { get; set; }
    public required string Descricao { get; set; }

    /// <summary>Foto opcional enviada pelo cliente como prova (ex.: comida estragada).</summary>
    public string? FotoUrl { get; set; }

    public StatusDenuncia Status { get; set; } = StatusDenuncia.Aberta;
    public string? Resposta { get; set; }
    public DateTimeOffset? TratadaEm { get; set; }
    public int? TratadaPorId { get; set; }
    public Usuario? TratadaPor { get; set; }

    public void Tratar(StatusDenuncia decisao, string resposta, int administradorId, DateTimeOffset agora)
    {
        if (Status != StatusDenuncia.Aberta)
            throw new RegraDeNegocioException("Esta denúncia já foi tratada.");
        if (decisao == StatusDenuncia.Aberta)
            throw new RegraDeNegocioException("Escolha procedente ou improcedente.");
        if (string.IsNullOrWhiteSpace(resposta))
            throw new RegraDeNegocioException("Escreva a resposta para o cliente.");

        Status = decisao;
        Resposta = resposta.Trim();
        TratadaPorId = administradorId;
        TratadaEm = agora;
    }
}
