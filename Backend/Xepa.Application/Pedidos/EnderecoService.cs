using Microsoft.EntityFrameworkCore;
using Xepa.Domain.Entities;

namespace Xepa.Application.Pedidos;

/// <summary>Endereços de entrega do cliente.</summary>
public class EnderecoService(IXepaDb db, IServicoMapas mapas)
{
    public async Task<IReadOnlyList<EnderecoDto>> ListarAsync(int usuarioId, CancellationToken ct) =>
        await db.Enderecos.AsNoTracking()
            .Where(e => e.UsuarioId == usuarioId)
            .OrderByDescending(e => e.Principal).ThenBy(e => e.Apelido)
            .Select(e => new EnderecoDto(e.Id, e.Apelido, e.Principal, e.Endereco))
            .ToListAsync(ct);

    public async Task<EnderecoDto> CriarAsync(int usuarioId, EnderecoRequest request, CancellationToken ct)
    {
        var existentes = await db.Enderecos.Where(e => e.UsuarioId == usuarioId).ToListAsync(ct);

        // O primeiro endereço vira o principal; um novo principal tira a marca dos outros.
        var principal = request.Principal || existentes.Count == 0;
        if (principal)
            existentes.ForEach(e => e.Principal = false);

        var endereco = new EnderecoUsuario
        {
            UsuarioId = usuarioId,
            Apelido = request.Apelido.Trim(),
            Principal = principal,
            Endereco = new Endereco
            {
                Cep = request.Cep,
                Logradouro = request.Logradouro.Trim(),
                Numero = request.Numero.Trim(),
                Complemento = request.Complemento?.Trim(),
                Bairro = request.Bairro.Trim(),
                Cidade = request.Cidade.Trim(),
                Uf = request.Uf,
                Latitude = request.Latitude,
                Longitude = request.Longitude
            }
        };
        endereco.Endereco = await LocalizarAsync(endereco.Endereco, ct);

        db.Enderecos.Add(endereco);
        await db.SaveChangesAsync(ct);

        return new EnderecoDto(endereco.Id, endereco.Apelido, endereco.Principal, endereco.Endereco);
    }

    /// <summary>
    /// O ponto de entrega vem do endereço digitado (Azure Maps). O GPS do aparelho só refina o ponto quando está
    /// a até 300 m dele: cadastrar a casa estando no trabalho não pode salvar o ponto do trabalho.
    /// Sem geocodificação (Azure Maps fora ou ambiente local), fica o GPS, se veio.
    /// </summary>
    private async Task<Endereco> LocalizarAsync(Endereco endereco, CancellationToken ct)
    {
        var ponto = await mapas.GeocodificarAsync(endereco, ct);
        if (ponto is null)
            return endereco;

        var gpsPerto = endereco.Latitude is { } lat && endereco.Longitude is { } lon
                       && Geo.DistanciaKm(ponto, new Coordenada(lat, lon)) <= RaioGpsKm;
        return gpsPerto ? endereco : endereco with { Latitude = ponto.Latitude, Longitude = ponto.Longitude };
    }

    private const double RaioGpsKm = 0.3;

    public async Task ExcluirAsync(int usuarioId, int enderecoId, CancellationToken ct)
    {
        var apagados = await db.Enderecos
            .Where(e => e.Id == enderecoId && e.UsuarioId == usuarioId)
            .ExecuteDeleteAsync(ct);
        if (apagados == 0)
            throw new NaoEncontradoException("Endereço não encontrado.");
    }
}
