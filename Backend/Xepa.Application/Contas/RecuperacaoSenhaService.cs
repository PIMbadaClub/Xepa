using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Contas;

public class SolicitarRecuperacaoRequest
{
    [Required(ErrorMessage = "Informe o e-mail."), EmailAddress(ErrorMessage = "E-mail inválido.")]
    public required string Email { get; init; }
}

public class RedefinirSenhaRequest
{
    [Required(ErrorMessage = "Informe o e-mail."), EmailAddress(ErrorMessage = "E-mail inválido.")]
    public required string Email { get; init; }

    [Required(ErrorMessage = "Informe o código."), RegularExpression(@"^\d{6}$", ErrorMessage = "O código tem 6 dígitos.")]
    public required string Codigo { get; init; }

    [Required, MinLength(8, ErrorMessage = "A nova senha precisa de ao menos 8 caracteres."), MaxLength(100)]
    public required string NovaSenha { get; init; }
}

/// <summary>
/// "Esqueci minha senha" do app e do portal: manda um código de 6 dígitos por e-mail e troca a senha com ele.
/// A resposta do pedido é sempre a mesma, exista ou não a conta, para não revelar quais e-mails são cadastrados.
/// </summary>
public class RecuperacaoSenhaService(IXepaDb db, IHasherSenha hasher, IEnvioEmail email)
{
    /// <summary>Intervalo mínimo entre dois e-mails para a mesma conta.</summary>
    private static readonly TimeSpan IntervaloReenvio = TimeSpan.FromSeconds(60);

    public async Task SolicitarAsync(string emailInformado, CancellationToken ct)
    {
        var normalizado = CredenciaisService.NormalizarEmail(emailInformado);
        var usuario = await db.Usuarios.FirstOrDefaultAsync(u => u.Email == normalizado && !u.Bloqueado, ct);
        if (usuario is null)
            return;

        var agora = DateTimeOffset.UtcNow;
        var abertos = await db.CodigosRecuperacao.Where(c => c.UsuarioId == usuario.Id && c.UsadoEm == null).ToListAsync(ct);
        if (abertos.Any(c => c.CriadoEm > agora - IntervaloReenvio))
            return;
        foreach (var c in abertos)
            c.UsadoEm = agora; // o código novo substitui os anteriores

        var codigo = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        db.CodigosRecuperacao.Add(new CodigoRecuperacaoSenha
        {
            UsuarioId = usuario.Id,
            CodigoHash = Hash(usuario.Id, codigo),
            CriadoEm = agora,
            ExpiraEm = agora + CodigoRecuperacaoSenha.Validade
        });
        await db.SaveChangesAsync(ct);

        await email.EnviarAsync(usuario.Email, usuario.Nome, $"{codigo} é o seu código da XEPA",
            CorpoHtml(usuario.Nome.Split(' ')[0], codigo),
            $"Olá, {usuario.Nome.Split(' ')[0]}! Seu código para criar uma nova senha na XEPA é {codigo}. " +
            "Ele vale por 15 minutos. Se não foi você que pediu, ignore este e-mail.", ct);
    }

    /// <summary>Confere o código e troca a senha; todas as sessões abertas da conta são encerradas.</summary>
    public async Task<Usuario> RedefinirAsync(RedefinirSenhaRequest request, CancellationToken ct)
    {
        var normalizado = CredenciaisService.NormalizarEmail(request.Email);
        var usuario = await db.Usuarios.Include(u => u.Estabelecimento)
            .FirstOrDefaultAsync(u => u.Email == normalizado && !u.Bloqueado, ct);
        var agora = DateTimeOffset.UtcNow;
        var registro = usuario is null
            ? null
            : await db.CodigosRecuperacao.Where(c => c.UsuarioId == usuario.Id && c.UsadoEm == null)
                .OrderByDescending(c => c.CriadoEm).FirstOrDefaultAsync(ct);

        if (usuario is null || registro is null || !registro.Valido(agora))
            throw new RegraDeNegocioException("Código expirado ou inválido. Peça um novo código.");

        if (!CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(registro.CodigoHash),
                Encoding.ASCII.GetBytes(Hash(usuario.Id, request.Codigo.Trim()))))
        {
            registro.Tentativas++;
            await db.SaveChangesAsync(ct);
            var restantes = CodigoRecuperacaoSenha.MaximoTentativas - registro.Tentativas;
            throw new RegraDeNegocioException(restantes > 0
                ? $"Código incorreto. Você ainda tem {restantes} {(restantes == 1 ? "tentativa" : "tentativas")}."
                : "Código incorreto. Peça um novo código.");
        }

        registro.UsadoEm = agora;
        usuario.SenhaHash = hasher.Gerar(usuario, request.NovaSenha);
        await foreach (var token in db.TokensRenovacao.Where(t => t.UsuarioId == usuario.Id && t.RevogadoEm == null)
                           .AsAsyncEnumerable().WithCancellation(ct))
            token.RevogadoEm = agora;
        await db.SaveChangesAsync(ct);
        return usuario;
    }

    private static string Hash(int usuarioId, string codigo) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{usuarioId}:{codigo}")));

    private static string CorpoHtml(string nome, string codigo) => $"""
        <div style="font-family:Arial,Helvetica,sans-serif;background:#FFFAF6;padding:24px">
          <div style="max-width:440px;margin:0 auto;background:#fff;border:1px solid #F0E6DF;border-radius:18px;overflow:hidden">
            <div style="background:#D7261E;color:#fff;padding:20px 24px;font-size:22px;font-weight:800">Xepa</div>
            <div style="padding:24px;color:#241A16">
              <p style="margin:0 0 12px;font-size:16px">Olá, {WebUtility.HtmlEncode(nome)}!</p>
              <p style="margin:0 0 18px;color:#7B6E66">Use este código para criar uma nova senha:</p>
              <div style="font-size:34px;font-weight:800;letter-spacing:10px;text-align:center;background:#FCE7E4;
                          color:#B71F18;border-radius:14px;padding:16px 0">{codigo}</div>
              <p style="margin:18px 0 0;color:#7B6E66;font-size:13px">Ele vale por 15 minutos. Se não foi você que pediu,
                 ignore este e-mail: sua senha continua a mesma.</p>
            </div>
          </div>
          <p style="text-align:center;color:#7B6E66;font-size:12px">XEPA · Comida boa não vai pro lixo</p>
        </div>
        """;
}
