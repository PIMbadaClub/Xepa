using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;
using Xepa.Application.Pedidos;
using Xepa.Domain;
using Xepa.Domain.Entities;
using Xepa.Infrastructure.Seguranca;
using Xepa.Web.Controllers;

namespace Xepa.Web;

/// <summary>
/// Cliente da API usado pelo portal para os pedidos: a API é quem muda o status e avisa o app
/// do cliente e o entregador em tempo real. O portal assina um JWT curto em nome do usuário logado.
/// </summary>
public class ApiXepa(HttpClient http, GeradorTokenJwt tokens, IHttpContextAccessor contexto)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() }
    };

    public Uri UrlBase => http.BaseAddress!;

    /// <summary>Token de acesso do usuário logado no portal (também usado pelo SignalR no navegador).</summary>
    public string TokenDoUsuario()
    {
        var u = contexto.HttpContext!.User;
        var usuario = new Usuario
        {
            Id = int.Parse(u.FindFirstValue(ClaimTypes.NameIdentifier)!),
            Nome = u.Identity!.Name!,
            Email = u.FindFirstValue(ClaimTypes.Email) ?? "",
            SenhaHash = "",
            Tipo = Enum.Parse<TipoUsuario>(u.FindFirstValue(ClaimTypes.Role)!)
        };
        var loja = u.FindFirstValue(ContaController.ClaimEstabelecimentoId);
        return tokens.GerarAcesso(usuario, loja is null ? null : int.Parse(loja));
    }

    public async Task<IReadOnlyList<PedidoLojaDto>> PedidosDaLojaAsync(CancellationToken ct)
    {
        using var resp = await EnviarAsync(HttpMethod.Get, "api/estabelecimento/pedidos", null, ct);
        return (await resp.Content.ReadFromJsonAsync<List<PedidoLojaDto>>(Json, ct))!;
    }

    public Task AlterarStatusAsync(int pedidoId, StatusPedido status, CancellationToken ct) =>
        EnviarSemRespostaAsync(HttpMethod.Patch, $"api/estabelecimento/pedidos/{pedidoId}/status", new { status = status.ToString() }, ct);

    public Task ConfirmarRetiradaAsync(int pedidoId, string codigo, CancellationToken ct) =>
        EnviarSemRespostaAsync(HttpMethod.Post, $"api/estabelecimento/pedidos/{pedidoId}/retirada", new { codigo }, ct);

    private async Task EnviarSemRespostaAsync(HttpMethod metodo, string caminho, object corpo, CancellationToken ct)
    {
        using var _ = await EnviarAsync(metodo, caminho, corpo, ct);
    }

    private async Task<HttpResponseMessage> EnviarAsync(HttpMethod metodo, string caminho, object? corpo, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(metodo, caminho);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", TokenDoUsuario());
        if (corpo is not null)
            req.Content = JsonContent.Create(corpo, options: Json);

        var resp = await http.SendAsync(req, ct);
        if (resp.IsSuccessStatusCode)
            return resp;

        // Erros de regra e de validação voltam como ProblemDetails: mostramos a mensagem para a loja.
        var problema = resp.Content.Headers.ContentType?.MediaType?.Contains("json") == true
            ? await resp.Content.ReadFromJsonAsync<ValidationProblemDetails>(Json, ct)
            : null;
        var status = resp.StatusCode;
        resp.Dispose();
        var mensagem = problema?.Errors.Values.SelectMany(v => v).FirstOrDefault() ?? problema?.Detail ?? problema?.Title;
        throw status switch
        {
            HttpStatusCode.UnprocessableEntity or HttpStatusCode.BadRequest => new RegraDeNegocioException(mensagem ?? "Operação não permitida."),
            HttpStatusCode.NotFound => new Application.NaoEncontradoException(mensagem ?? "Pedido não encontrado."),
            _ => new InvalidOperationException($"API respondeu {(int)status} em {caminho}.")
        };
    }
}
