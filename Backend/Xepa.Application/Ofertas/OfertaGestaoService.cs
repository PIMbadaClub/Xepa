using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Ofertas;

/// <summary>Dados do formulário de oferta do portal do estabelecimento.</summary>
public class OfertaForm
{
    public TipoOferta Tipo { get; set; } = TipoOferta.SacolaSurpresa;

    [Required(ErrorMessage = "Informe o título."), MaxLength(120)]
    [Display(Name = "Título")]
    public string Titulo { get; set; } = "";

    [MaxLength(1000)]
    [Display(Name = "Descrição")]
    public string? Descricao { get; set; }

    [Range(0.01, 10000, ErrorMessage = "Informe o preço original.")]
    [Display(Name = "Preço original (R$)")]
    public decimal PrecoOriginal { get; set; }

    [Range(0.01, 10000, ErrorMessage = "Informe o preço com desconto.")]
    [Display(Name = "Preço com desconto (R$)")]
    public decimal Preco { get; set; }

    [Range(0, 1000)]
    [Display(Name = "Quantidade disponível")]
    public int QuantidadeDisponivel { get; set; } = 1;

    [Range(0, 100)]
    [Display(Name = "Peso estimado por unidade (kg)")]
    public decimal? PesoEstimadoKg { get; set; }

    [Display(Name = "Retirada a partir de")]
    public DateTime RetiradaInicio { get; set; }

    [Display(Name = "Retirada até")]
    public DateTime RetiradaFim { get; set; }

    public string? FotoUrl { get; set; }
}

public record OfertaLojaDto(int Id, TipoOferta Tipo, string Titulo, string? FotoUrl, decimal PrecoOriginal, decimal Preco,
    int QuantidadeDisponivel, DateTimeOffset RetiradaInicio, DateTimeOffset RetiradaFim, bool Ativa, int Pedidos);

/// <summary>
/// Cadastro de ofertas pelo estabelecimento no portal. Os horários do formulário são de Brasília
/// e são gravados em UTC.
/// </summary>
public class OfertaGestaoService(IXepaDb db, IArmazenamento armazenamento)
{
    public static readonly TimeZoneInfo FusoBrasilia = TimeZoneInfo.FindSystemTimeZoneById("America/Sao_Paulo");

    public const long TamanhoMaximoFoto = Fotos.TamanhoMaximo;

    public async Task<IReadOnlyList<OfertaLojaDto>> ListarAsync(int estabelecimentoId, CancellationToken ct) =>
        await db.Ofertas.AsNoTracking()
            .Where(o => o.EstabelecimentoId == estabelecimentoId)
            .OrderByDescending(o => o.Ativa).ThenByDescending(o => o.RetiradaFim)
            .Select(o => new OfertaLojaDto(o.Id, o.Tipo, o.Titulo, o.FotoUrl, o.PrecoOriginal, o.Preco,
                o.QuantidadeDisponivel, o.RetiradaInicio, o.RetiradaFim, o.Ativa, o.Pedidos.Count))
            .ToListAsync(ct);

    public async Task<OfertaForm> ObterFormAsync(int estabelecimentoId, int ofertaId, CancellationToken ct)
    {
        var o = await BuscarAsync(estabelecimentoId, ofertaId, ct);
        return new OfertaForm
        {
            Tipo = o.Tipo,
            Titulo = o.Titulo,
            Descricao = o.Descricao,
            PrecoOriginal = o.PrecoOriginal,
            Preco = o.Preco,
            QuantidadeDisponivel = o.QuantidadeDisponivel,
            PesoEstimadoKg = o.PesoEstimadoKg,
            RetiradaInicio = TimeZoneInfo.ConvertTime(o.RetiradaInicio, FusoBrasilia).DateTime,
            RetiradaFim = TimeZoneInfo.ConvertTime(o.RetiradaFim, FusoBrasilia).DateTime,
            FotoUrl = o.FotoUrl
        };
    }

    public async Task<int> CriarAsync(int estabelecimentoId, OfertaForm form, Foto? foto, CancellationToken ct)
    {
        var oferta = new Oferta { EstabelecimentoId = estabelecimentoId, Titulo = "" };
        await AplicarAsync(oferta, form, foto, ct);
        db.Ofertas.Add(oferta);
        await db.SaveChangesAsync(ct);
        return oferta.Id;
    }

    public async Task AtualizarAsync(int estabelecimentoId, int ofertaId, OfertaForm form, Foto? foto, CancellationToken ct)
    {
        var oferta = await BuscarAsync(estabelecimentoId, ofertaId, ct);
        await AplicarAsync(oferta, form, foto, ct);
        await db.SaveChangesAsync(ct);
    }

    /// <summary>Tira a oferta do ar sem apagá-la (RN06).</summary>
    public async Task AlterarAtivaAsync(int estabelecimentoId, int ofertaId, bool ativa, CancellationToken ct)
    {
        var oferta = await BuscarAsync(estabelecimentoId, ofertaId, ct);
        oferta.Ativa = ativa;
        await db.SaveChangesAsync(ct);
    }

    private async Task AplicarAsync(Oferta oferta, OfertaForm form, Foto? foto, CancellationToken ct)
    {
        oferta.Tipo = form.Tipo;
        oferta.Titulo = form.Titulo.Trim();
        oferta.Descricao = string.IsNullOrWhiteSpace(form.Descricao) ? null : form.Descricao.Trim();
        oferta.PrecoOriginal = form.PrecoOriginal;
        oferta.Preco = form.Preco;
        oferta.QuantidadeDisponivel = form.QuantidadeDisponivel;
        oferta.PesoEstimadoKg = form.PesoEstimadoKg;
        oferta.RetiradaInicio = DeBrasilia(form.RetiradaInicio);
        oferta.RetiradaFim = DeBrasilia(form.RetiradaFim);
        oferta.Validar();

        if (foto is not null)
            oferta.FotoUrl = await Fotos.SalvarAsync(armazenamento, foto, ct);
    }

    private async Task<Oferta> BuscarAsync(int estabelecimentoId, int ofertaId, CancellationToken ct) =>
        await db.Ofertas.FirstOrDefaultAsync(o => o.Id == ofertaId && o.EstabelecimentoId == estabelecimentoId, ct)
        ?? throw new NaoEncontradoException("Oferta não encontrada.");

    private static DateTimeOffset DeBrasilia(DateTime horaLocal)
    {
        var local = DateTime.SpecifyKind(horaLocal, DateTimeKind.Unspecified);
        return new DateTimeOffset(local, FusoBrasilia.GetUtcOffset(local)).ToUniversalTime();
    }
}

