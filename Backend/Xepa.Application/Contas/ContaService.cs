using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Contas;

/// <summary>Confere e-mail e senha. Usado pelo app (via ContaService) e pelo portal, que abre sessão por cookie.</summary>
public class CredenciaisService(IXepaDb db, IHasherSenha hasher)
{
    public async Task<Usuario?> ValidarAsync(string email, string senha, CancellationToken ct)
    {
        var normalizado = NormalizarEmail(email);
        var usuario = await db.Usuarios
            .Include(u => u.Estabelecimento)
            .FirstOrDefaultAsync(u => u.Email == normalizado, ct);

        if (usuario is null || !hasher.Conferir(usuario, senha))
            return null;
        if (usuario.Bloqueado)
            throw new AcessoNegadoException("Esta conta está suspensa. Fale com o suporte da XEPA.");
        return usuario;
    }

    public static string NormalizarEmail(string email) => email.Trim().ToLowerInvariant();
}

/// <summary>Cadastro, login e sessões do app (token de acesso de 15 min + token de renovação de 7 dias).</summary>
public class ContaService(IXepaDb db, IHasherSenha hasher, CredenciaisService credenciais, IGeradorToken geradorToken,
    RecuperacaoSenhaService recuperacao)
{
    public static readonly TimeSpan ValidadeRenovacao = TimeSpan.FromDays(7);

    public async Task<SessaoDto> RegistrarAsync(RegistrarRequest request, CancellationToken ct)
    {
        var email = CredenciaisService.NormalizarEmail(request.Email);
        if (await db.Usuarios.AnyAsync(u => u.Email == email, ct))
            throw new RegraDeNegocioException("Já existe uma conta com este e-mail.");

        var usuario = new Usuario
        {
            Nome = request.Nome.Trim(),
            Email = email,
            Telefone = request.Telefone,
            Tipo = request.Tipo,
            Placa = request.Tipo == TipoUsuario.Entregador ? request.Placa!.Replace("-", "").ToUpperInvariant() : null,
            CadastroEntregador = request.Tipo == TipoUsuario.Entregador ? StatusCadastro.Pendente : null,
            SenhaHash = ""
        };
        usuario.SenhaHash = hasher.Gerar(usuario, request.Senha);
        db.Usuarios.Add(usuario);

        return await AbrirSessaoAsync(usuario, ct);
    }

    public async Task<SessaoDto> LoginAsync(LoginRequest request, CancellationToken ct)
    {
        var usuario = await credenciais.ValidarAsync(request.Email, request.Senha, ct)
                      ?? throw new AcessoNegadoException("E-mail ou senha incorretos.");

        return await AbrirSessaoAsync(usuario, ct);
    }

    /// <summary>
    /// "Continuar com Google": entra na conta já vinculada, vincula a conta do mesmo e-mail (o Google confirmou o e-mail)
    /// ou cria uma conta de cliente nova. Lojas e administração seguem entrando pelo portal.
    /// </summary>
    public async Task<SessaoDto> EntrarComGoogleAsync(ContaGoogle google, CancellationToken ct)
    {
        var email = CredenciaisService.NormalizarEmail(google.Email);
        var usuario = await db.Usuarios.Include(u => u.Estabelecimento).FirstOrDefaultAsync(u => u.GoogleId == google.Id, ct)
                      ?? await db.Usuarios.Include(u => u.Estabelecimento).FirstOrDefaultAsync(u => u.Email == email, ct);

        if (usuario is null)
        {
            usuario = new Usuario { Nome = google.Nome.Trim(), Email = email, Tipo = TipoUsuario.Cliente, SenhaHash = "" };
            // Sem senha própria: a conta entra pelo Google (ou cria uma senha em "Esqueci minha senha").
            usuario.SenhaHash = hasher.Gerar(usuario, Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)));
            db.Usuarios.Add(usuario);
        }
        if (usuario.Tipo is TipoUsuario.Estabelecimento or TipoUsuario.Administrador)
            throw new RegraDeNegocioException("Essa conta é de loja ou da administração: entre pelo portal da XEPA.");
        if (usuario.Bloqueado)
            throw new AcessoNegadoException("Esta conta está suspensa. Fale com o suporte da XEPA.");

        usuario.GoogleId ??= google.Id;
        return await AbrirSessaoAsync(usuario, ct);
    }

    /// <summary>Nova senha com o código do e-mail; já devolve a sessão aberta no aparelho.</summary>
    public async Task<SessaoDto> RedefinirSenhaAsync(RedefinirSenhaRequest request, CancellationToken ct) =>
        await AbrirSessaoAsync(await recuperacao.RedefinirAsync(request, ct), ct);

    /// <summary>Troca o token de renovação por uma sessão nova; o token usado é revogado (rotação).</summary>
    public async Task<SessaoDto> RenovarAsync(string tokenRenovacao, CancellationToken ct)
    {
        var hash = Hash(tokenRenovacao);
        var token = await db.TokensRenovacao
            .Include(t => t.Usuario).ThenInclude(u => u.Estabelecimento)
            .FirstOrDefaultAsync(t => t.TokenHash == hash, ct);

        var agora = DateTimeOffset.UtcNow;
        if (token is null || !token.Valido(agora) || token.Usuario.Bloqueado)
            throw new AcessoNegadoException("Sessão expirada. Entre novamente.");

        token.RevogadoEm = agora;
        return await AbrirSessaoAsync(token.Usuario, ct);
    }

    /// <summary>Logout: revoga o token de renovação do aparelho.</summary>
    public async Task SairAsync(string tokenRenovacao, CancellationToken ct)
    {
        var hash = Hash(tokenRenovacao);
        var token = await db.TokensRenovacao.FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (token is { RevogadoEm: null })
        {
            token.RevogadoEm = DateTimeOffset.UtcNow;
            await db.SaveChangesAsync(ct);
        }
    }

    public async Task<UsuarioDto> ObterAsync(int usuarioId, CancellationToken ct)
    {
        var usuario = await db.Usuarios.Include(u => u.Estabelecimento).FirstOrDefaultAsync(u => u.Id == usuarioId, ct)
                      ?? throw new NaoEncontradoException("Usuário não encontrado.");
        return ParaDto(usuario);
    }

    public async Task<UsuarioDto> AtualizarPerfilAsync(int usuarioId, AtualizarPerfilRequest request, CancellationToken ct)
    {
        var usuario = await db.Usuarios.Include(u => u.Estabelecimento).FirstOrDefaultAsync(u => u.Id == usuarioId, ct)
                      ?? throw new NaoEncontradoException("Usuário não encontrado.");
        usuario.Nome = request.Nome.Trim();
        usuario.Telefone = string.IsNullOrWhiteSpace(request.Telefone) ? null : request.Telefone.Trim();
        await db.SaveChangesAsync(ct);
        return ParaDto(usuario);
    }

    /// <summary>Troca a senha conferindo a atual; as outras sessões abertas são encerradas.</summary>
    public async Task AlterarSenhaAsync(int usuarioId, AlterarSenhaRequest request, string? tokenRenovacaoAtual, CancellationToken ct)
    {
        var usuario = await db.Usuarios.FirstOrDefaultAsync(u => u.Id == usuarioId, ct)
                      ?? throw new NaoEncontradoException("Usuário não encontrado.");
        if (!hasher.Conferir(usuario, request.SenhaAtual))
            throw new RegraDeNegocioException("A senha atual não confere.");
        if (request.SenhaAtual == request.NovaSenha)
            throw new RegraDeNegocioException("A nova senha precisa ser diferente da atual.");

        usuario.SenhaHash = hasher.Gerar(usuario, request.NovaSenha);
        var manter = tokenRenovacaoAtual is null ? null : Hash(tokenRenovacaoAtual);
        var agora = DateTimeOffset.UtcNow;
        await foreach (var token in db.TokensRenovacao.Where(t => t.UsuarioId == usuarioId && t.RevogadoEm == null && t.TokenHash != manter)
                           .AsAsyncEnumerable().WithCancellation(ct))
            token.RevogadoEm = agora;
        await db.SaveChangesAsync(ct);
    }

    private async Task<SessaoDto> AbrirSessaoAsync(Usuario usuario, CancellationToken ct)
    {
        var agora = DateTimeOffset.UtcNow;
        var renovacao = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
            .Replace('+', '-').Replace('/', '_').TrimEnd('=');

        usuario.TokensRenovacao.Add(new TokenRenovacao
        {
            TokenHash = Hash(renovacao),
            ExpiraEm = agora + ValidadeRenovacao,
            CriadoEm = agora
        });
        await db.SaveChangesAsync(ct);

        var acesso = geradorToken.GerarAcesso(usuario, usuario.Estabelecimento?.Id);
        return new SessaoDto(acesso, agora + geradorToken.ValidadeAcesso, renovacao, agora + ValidadeRenovacao,
            ParaDto(usuario));
    }

    private static UsuarioDto ParaDto(Usuario u) =>
        new(u.Id, u.Nome, u.Email, u.Telefone, u.Tipo, u.Estabelecimento?.Id);

    private static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
