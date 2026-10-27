using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Xepa.Application;
using Xepa.Application.Notificacoes;
using Xepa.Application.Pagamentos;

namespace Xepa.Infrastructure.Integracoes;

/// <summary>
/// Firebase Cloud Messaging (API HTTP v1). A credencial é o JSON da conta de serviço do projeto Firebase
/// (configuração Firebase:ContaServico); o token de acesso do Google é renovado sozinho pela biblioteca.
/// </summary>
public class EnvioPushFcm(HttpClient http, string contaServicoJson, ILogger<EnvioPushFcm> log) : IEnvioPush
{
    private readonly GoogleCredential credencial = CredentialFactory.FromJson<ServiceAccountCredential>(contaServicoJson)
        .ToGoogleCredential().CreateScoped("https://www.googleapis.com/auth/firebase.messaging");

    private readonly string projeto = JsonDocument.Parse(contaServicoJson).RootElement.GetProperty("project_id").GetString()!;

    public async Task<IReadOnlyCollection<string>> EnviarAsync(IReadOnlyCollection<string> tokens, string titulo, string texto,
        IReadOnlyDictionary<string, string> dados, CancellationToken ct)
    {
        var acesso = await credencial.UnderlyingCredential.GetAccessTokenForRequestAsync(cancellationToken: ct);
        var invalidos = new List<string>();
        foreach (var token in tokens)
        {
            using var requisicao = new HttpRequestMessage(HttpMethod.Post, $"https://fcm.googleapis.com/v1/projects/{projeto}/messages:send")
            {
                Content = JsonContent.Create(new
                {
                    message = new
                    {
                        token,
                        notification = new { title = titulo, body = texto },
                        data = dados,
                        android = new { priority = "high", notification = new { color = "#D7261E" } }
                    }
                })
            };
            requisicao.Headers.Authorization = new AuthenticationHeaderValue("Bearer", acesso);
            using var resposta = await http.SendAsync(requisicao, ct);
            if (resposta.IsSuccessStatusCode)
                continue;

            var corpo = await resposta.Content.ReadAsStringAsync(ct);
            // 404 UNREGISTERED / 400 INVALID_ARGUMENT no token: o app foi desinstalado ou o token expirou.
            if (resposta.StatusCode == HttpStatusCode.NotFound || corpo.Contains("UNREGISTERED") || corpo.Contains("registration token"))
                invalidos.Add(token);
            else
                log.LogWarning("FCM recusou o push ({Status}): {Corpo}", (int)resposta.StatusCode, corpo);
        }
        return invalidos;
    }
}

/// <summary>Sem Firebase configurado (desenvolvimento): o aviso vai para o log.</summary>
public class EnvioPushLog(ILogger<EnvioPushLog> log) : IEnvioPush
{
    public Task<IReadOnlyCollection<string>> EnviarAsync(IReadOnlyCollection<string> tokens, string titulo, string texto,
        IReadOnlyDictionary<string, string> dados, CancellationToken ct)
    {
        log.LogInformation("Push não enviado (sem Firebase:ContaServico) para {Aparelhos} aparelho(s): {Titulo} | {Texto}",
            tokens.Count, titulo, texto);
        return Task.FromResult<IReadOnlyCollection<string>>([]);
    }
}

/// <summary>
/// Acrescenta o push ao aviso de pedido alterado: a API continua mandando pelo SignalR (app aberto) e o portal, que não
/// tem canal em tempo real, passa a avisar o cliente pelo celular quando a loja muda o status.
/// </summary>
public class NotificadorComPush(INotificadorPedidos interno, IServiceScopeFactory scopes) : INotificadorPedidos
{
    public async Task PedidoAlteradoAsync(int pedidoId, CancellationToken ct)
    {
        await interno.PedidoAlteradoAsync(pedidoId, ct);
        using var scope = scopes.CreateScope();
        await scope.ServiceProvider.GetRequiredService<PushService>().AvisarPedidoAsync(pedidoId, ct);
    }

    public Task PosicaoEntregadorAsync(int pedidoId, double latitude, double longitude, CancellationToken ct) =>
        interno.PosicaoEntregadorAsync(pedidoId, latitude, longitude, ct);
}
