using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.IdentityModel.JsonWebTokens;
using Xepa.Application;
using Xepa.Application.Contas;
using Xepa.Domain;

namespace Xepa.Api.Seguranca;

public class OpcoesGoogle
{
    public string? ClientId { get; init; }
    public string? ClientSecret { get; init; }
    public bool Configurado => !string.IsNullOrWhiteSpace(ClientId) && !string.IsNullOrWhiteSpace(ClientSecret);
}

/// <summary>
/// "Continuar com Google" pelo fluxo de código do OAuth, todo no servidor (o segredo nunca vai para o app):
/// o app abre /api/auth/google, o Google volta em /api/auth/google/retorno, a API confere a conta e devolve ao app
/// um código de uso único (2 min) que ele troca pela sessão normal do XEPA.
/// </summary>
public class LoginGoogle(OpcoesGoogle opcoes, IHttpClientFactory http)
{
    private static readonly TimeSpan ValidadeEstado = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan ValidadeCodigo = TimeSpan.FromMinutes(2);

    // Uma instância só (App Service B1): guardar em memória basta para estados e códigos de poucos minutos.
    private readonly ConcurrentDictionary<string, (string Retorno, DateTimeOffset Expira)> _estados = new();
    private readonly ConcurrentDictionary<string, (SessaoDto Sessao, DateTimeOffset Expira)> _codigos = new();

    public bool Configurado => opcoes.Configurado;

    public string UrlAutorizacao(string retorno, string urlCallback)
    {
        Limpar();
        var estado = Aleatorio();
        _estados[estado] = (retorno, DateTimeOffset.UtcNow + ValidadeEstado);
        return "https://accounts.google.com/o/oauth2/v2/auth?" + string.Join("&",
            $"client_id={Uri.EscapeDataString(opcoes.ClientId!)}",
            $"redirect_uri={Uri.EscapeDataString(urlCallback)}",
            "response_type=code",
            $"scope={Uri.EscapeDataString("openid email profile")}",
            $"state={estado}",
            "prompt=select_account");
    }

    /// <summary>Confere o estado e troca o código do Google pelos dados da conta (e-mail verificado e nome).</summary>
    public async Task<(string Retorno, ContaGoogle Conta)> ConcluirAsync(string estado, string codigo, string urlCallback,
        CancellationToken ct)
    {
        if (!_estados.TryRemove(estado, out var e) || e.Expira < DateTimeOffset.UtcNow)
            throw new RegraDeNegocioException("O login com Google expirou. Tente de novo.");

        using var resposta = await http.CreateClient().PostAsync("https://oauth2.googleapis.com/token",
            new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["code"] = codigo,
                ["client_id"] = opcoes.ClientId!,
                ["client_secret"] = opcoes.ClientSecret!,
                ["redirect_uri"] = urlCallback,
                ["grant_type"] = "authorization_code"
            }), ct);
        if (!resposta.IsSuccessStatusCode)
            throw new RegraDeNegocioException("O Google não confirmou o login. Tente de novo.");

        using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync(ct));
        // O id_token veio direto do Google por HTTPS com o nosso segredo: basta conferir para quem e por quem foi emitido.
        var token = new JsonWebToken(json.RootElement.GetProperty("id_token").GetString());
        var emissorOk = token.Issuer is "https://accounts.google.com" or "accounts.google.com";
        if (!emissorOk || !token.Audiences.Contains(opcoes.ClientId) || token.ValidTo < DateTime.UtcNow.AddMinutes(-5))
            throw new RegraDeNegocioException("O Google não confirmou o login. Tente de novo.");
        if (!token.TryGetPayloadValue<bool>("email_verified", out var verificado) || !verificado)
            throw new RegraDeNegocioException("Confirme o seu e-mail no Google antes de entrar com ele.");

        token.TryGetPayloadValue<string>("name", out var nome);
        var email = token.GetPayloadValue<string>("email");
        return (e.Retorno, new ContaGoogle(token.Subject, email, string.IsNullOrWhiteSpace(nome) ? email.Split('@')[0] : nome));
    }

    public string GuardarSessao(SessaoDto sessao)
    {
        var codigo = Aleatorio();
        _codigos[codigo] = (sessao, DateTimeOffset.UtcNow + ValidadeCodigo);
        return codigo;
    }

    public SessaoDto TrocarCodigo(string codigo) =>
        _codigos.TryRemove(codigo, out var c) && c.Expira > DateTimeOffset.UtcNow
            ? c.Sessao
            : throw new AcessoNegadoException("O login com Google expirou. Tente de novo.");

    private void Limpar()
    {
        var agora = DateTimeOffset.UtcNow;
        foreach (var (k, v) in _estados)
            if (v.Expira < agora) _estados.TryRemove(k, out _);
        foreach (var (k, v) in _codigos)
            if (v.Expira < agora) _codigos.TryRemove(k, out _);
    }

    private static string Aleatorio() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).Replace('+', '-').Replace('/', '_').TrimEnd('=');
}
