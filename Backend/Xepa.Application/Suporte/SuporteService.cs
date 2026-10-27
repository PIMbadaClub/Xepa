using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;
using Xepa.Application.Notificacoes;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Suporte;

public class EnviarMensagemSuporteRequest
{
    [Required(ErrorMessage = "Escreva a mensagem."), StringLength(2000, ErrorMessage = "A mensagem pode ter até 2000 caracteres.")]
    public string Texto { get; set; } = "";

    /// <summary>Pedido anexado (opcional): precisa ser do próprio usuário (ou da loja, ou entregue por ele).</summary>
    public int? PedidoId { get; set; }
}

public record PedidoAnexoDto(int Id, string Loja, string Oferta, decimal ValorTotal, StatusPedido Status, TipoEntrega TipoEntrega,
    DateTimeOffset CriadoEm);

public record MensagemSuporteDto(int Id, bool DoSuporte, bool Automatica, string Autor, string Texto, DateTimeOffset Em,
    PedidoAnexoDto? Pedido);

public record ConversaSuporteDto(int? Id, StatusConversa Status, IReadOnlyList<MensagemSuporteDto> Mensagens, bool AtendimentoAgora);

public record ConversaResumoDto(int Id, int UsuarioId, string Usuario, TipoUsuario Tipo, string? Loja, StatusConversa Status,
    DateTimeOffset UltimaMensagemEm, string UltimaMensagem, bool UltimaDoSuporte, int NaoLidas);

public record ConversaAdminDto(int Id, int UsuarioId, string Usuario, string Email, string? Telefone, TipoUsuario Tipo, string? Loja,
    StatusConversa Status, IReadOnlyList<MensagemSuporteDto> Mensagens, IReadOnlyList<PedidoAnexoDto> PedidosRecentes);

/// <summary>
/// Chat de suporte (como o atendimento dos marketplaces): o usuário escreve pelo app ou pelo portal da loja, pode anexar
/// um pedido, recebe uma resposta automática na abertura e a equipe da XEPA responde pelo portal administrativo.
/// </summary>
public class SuporteService(IXepaDb db, PushService push)
{
    public const string NomeEquipe = "Equipe XEPA";

    private static readonly TimeZoneInfo Fuso = TimeZoneInfo.FindSystemTimeZoneById("America/Sao_Paulo");

    /// <summary>Atendimento humano das 8h às 22h (horário de Brasília); fora disso a resposta automática avisa.</summary>
    public static bool AtendimentoAgora(DateTimeOffset agora) => TimeZoneInfo.ConvertTime(agora, Fuso).Hour is >= 8 and < 22;

    // ---------- Lado do usuário (app e portal da loja) ----------

    /// <summary>A conversa do usuário, já marcando as respostas da equipe como lidas.</summary>
    public async Task<ConversaSuporteDto> ConversaAsync(int usuarioId, int? depoisDe, CancellationToken ct)
    {
        var conversa = await db.ConversasSuporte.FirstOrDefaultAsync(c => c.UsuarioId == usuarioId, ct);
        var agora = DateTimeOffset.UtcNow;
        if (conversa is null)
            return new ConversaSuporteDto(null, StatusConversa.Aberta, [], AtendimentoAgora(agora));

        if (conversa.NaoLidasUsuario > 0)
        {
            conversa.NaoLidasUsuario = 0;
            await db.SaveChangesAsync(ct);
        }
        return new ConversaSuporteDto(conversa.Id, conversa.Status, await MensagensAsync(conversa.Id, depoisDe, ct), AtendimentoAgora(agora));
    }

    public async Task<int> NaoLidasAsync(int usuarioId, CancellationToken ct) =>
        await db.ConversasSuporte.Where(c => c.UsuarioId == usuarioId).Select(c => c.NaoLidasUsuario).FirstOrDefaultAsync(ct);

    public async Task<ConversaSuporteDto> EnviarAsync(int usuarioId, EnviarMensagemSuporteRequest request, CancellationToken ct)
    {
        var texto = Validar(request.Texto);
        var usuario = await db.Usuarios.Include(u => u.Estabelecimento).FirstOrDefaultAsync(u => u.Id == usuarioId, ct)
                      ?? throw new NaoEncontradoException("Usuário não encontrado.");
        if (request.PedidoId is { } pedidoId && !await PedidosDoUsuario(usuario).AnyAsync(p => p.Id == pedidoId, ct))
            throw new RegraDeNegocioException("Esse pedido não é seu.");

        var agora = DateTimeOffset.UtcNow;
        var conversa = await db.ConversasSuporte.FirstOrDefaultAsync(c => c.UsuarioId == usuarioId, ct);
        var abrindo = conversa is null || conversa.Status == StatusConversa.Resolvida;
        if (conversa is null)
        {
            conversa = new ConversaSuporte { UsuarioId = usuarioId };
            db.ConversasSuporte.Add(conversa);
        }

        conversa.Status = StatusConversa.Aberta;
        conversa.UltimaMensagemEm = agora;
        conversa.NaoLidasSuporte++;
        conversa.Mensagens.Add(new MensagemSuporte { AutorId = usuarioId, Texto = texto, PedidoId = request.PedidoId });

        // Ao abrir (ou reabrir) o atendimento, a resposta automática diz quando alguém vai responder.
        if (abrindo)
        {
            var primeiroNome = usuario.Nome.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? usuario.Nome;
            var dica = request.PedidoId is null ? " Se for sobre um pedido, anexe ele no clipe para agilizar." : "";
            conversa.Mensagens.Add(new MensagemSuporte
            {
                DoSuporte = true,
                Automatica = true,
                Texto = AtendimentoAgora(agora)
                    ? $"Oi, {primeiroNome}! Recebemos sua mensagem e alguém da equipe XEPA já vai te responder por aqui.{dica}"
                    : $"Oi, {primeiroNome}! Recebemos sua mensagem. Nosso atendimento funciona das 8h às 22h e vamos te responder por aqui logo cedo.{dica}"
            });
        }
        await db.SaveChangesAsync(ct);
        return new ConversaSuporteDto(conversa.Id, conversa.Status, await MensagensAsync(conversa.Id, null, ct), AtendimentoAgora(agora));
    }

    /// <summary>Pedidos que o usuário pode anexar: os que fez, os que entregou ou, para a loja, os que recebeu.</summary>
    public async Task<IReadOnlyList<PedidoAnexoDto>> PedidosParaAnexarAsync(int usuarioId, CancellationToken ct)
    {
        var usuario = await db.Usuarios.Include(u => u.Estabelecimento).FirstOrDefaultAsync(u => u.Id == usuarioId, ct)
                      ?? throw new NaoEncontradoException("Usuário não encontrado.");
        return await Anexos(PedidosDoUsuario(usuario).Where(p => p.Status != StatusPedido.AguardandoPagamento)
            .OrderByDescending(p => p.CriadoEm).Take(15)).ToListAsync(ct);
    }

    // ---------- Lado da equipe (portal administrativo) ----------

    public async Task<IReadOnlyList<ConversaResumoDto>> ListarAsync(StatusConversa? status, string? busca, CancellationToken ct)
    {
        var consulta = db.ConversasSuporte.AsNoTracking();
        if (status is { } s)
            consulta = consulta.Where(c => c.Status == s);
        if (!string.IsNullOrWhiteSpace(busca))
        {
            var termo = busca.Trim();
            consulta = consulta.Where(c => c.Usuario.Nome.Contains(termo) || c.Usuario.Email.Contains(termo)
                                           || (c.Usuario.Estabelecimento != null && c.Usuario.Estabelecimento.Nome.Contains(termo)));
        }
        return await consulta
            .OrderByDescending(c => c.NaoLidasSuporte > 0).ThenByDescending(c => c.UltimaMensagemEm)
            .Take(200)
            .Select(c => new ConversaResumoDto(c.Id, c.UsuarioId, c.Usuario.Nome, c.Usuario.Tipo,
                c.Usuario.Estabelecimento != null ? c.Usuario.Estabelecimento.Nome : null, c.Status, c.UltimaMensagemEm,
                c.Mensagens.Where(m => !m.Automatica).OrderByDescending(m => m.Id).Select(m => m.Texto).FirstOrDefault() ?? "",
                c.Mensagens.Where(m => !m.Automatica).OrderByDescending(m => m.Id).Select(m => m.DoSuporte).FirstOrDefault(),
                c.NaoLidasSuporte))
            .ToListAsync(ct);
    }

    /// <summary>Quantas conversas têm mensagem do usuário ainda não lida pela equipe (bolinha no menu).</summary>
    public Task<int> NaoLidasEquipeAsync(CancellationToken ct) => db.ConversasSuporte.CountAsync(c => c.NaoLidasSuporte > 0, ct);

    /// <summary>A conversa com os dados do usuário e os pedidos recentes dele, já marcando como lida pela equipe.</summary>
    public async Task<ConversaAdminDto> ObterAdminAsync(int conversaId, CancellationToken ct)
    {
        var conversa = await db.ConversasSuporte.Include(c => c.Usuario).ThenInclude(u => u.Estabelecimento)
                           .FirstOrDefaultAsync(c => c.Id == conversaId, ct)
                       ?? throw new NaoEncontradoException("Conversa não encontrada.");
        if (conversa.NaoLidasSuporte > 0)
        {
            conversa.NaoLidasSuporte = 0;
            await db.SaveChangesAsync(ct);
        }
        var u = conversa.Usuario;
        var pedidos = await Anexos(PedidosDoUsuario(u).Where(p => p.Status != StatusPedido.AguardandoPagamento)
            .OrderByDescending(p => p.CriadoEm).Take(8)).ToListAsync(ct);
        return new ConversaAdminDto(conversa.Id, u.Id, u.Nome, u.Email, u.Telefone, u.Tipo, u.Estabelecimento?.Nome, conversa.Status,
            await MensagensAsync(conversa.Id, null, ct), pedidos);
    }

    /// <summary>Mensagens novas para o portal ir atualizando a conversa aberta (e marcar como lidas).</summary>
    public async Task<IReadOnlyList<MensagemSuporteDto>> NovasAdminAsync(int conversaId, int depoisDe, CancellationToken ct)
    {
        var conversa = await db.ConversasSuporte.FirstOrDefaultAsync(c => c.Id == conversaId, ct)
                       ?? throw new NaoEncontradoException("Conversa não encontrada.");
        if (conversa.NaoLidasSuporte > 0)
        {
            conversa.NaoLidasSuporte = 0;
            await db.SaveChangesAsync(ct);
        }
        return await MensagensAsync(conversaId, depoisDe, ct);
    }

    public async Task ResponderAsync(int conversaId, int atendenteId, string texto, CancellationToken ct)
    {
        texto = Validar(texto);
        var conversa = await db.ConversasSuporte.FirstOrDefaultAsync(c => c.Id == conversaId, ct)
                       ?? throw new NaoEncontradoException("Conversa não encontrada.");
        conversa.Mensagens.Add(new MensagemSuporte { AutorId = atendenteId, DoSuporte = true, Texto = texto });
        conversa.Status = StatusConversa.Aberta;
        conversa.UltimaMensagemEm = DateTimeOffset.UtcNow;
        conversa.NaoLidasUsuario++;
        conversa.NaoLidasSuporte = 0;
        await db.SaveChangesAsync(ct);

        // Usuários do app recebem no celular; a loja vê a bolinha no menu do portal.
        await push.AvisarAsync(conversa.UsuarioId, "A equipe XEPA respondeu", texto.Length > 140 ? texto[..137] + "..." : texto,
            new Dictionary<string, string> { ["tipo"] = "suporte" }, ct);
    }

    /// <summary>Encerra o atendimento; se o usuário escrever de novo, a conversa reabre.</summary>
    public async Task ResolverAsync(int conversaId, CancellationToken ct)
    {
        var conversa = await db.ConversasSuporte.FirstOrDefaultAsync(c => c.Id == conversaId, ct)
                       ?? throw new NaoEncontradoException("Conversa não encontrada.");
        if (conversa.Status == StatusConversa.Resolvida)
            return;
        conversa.Status = StatusConversa.Resolvida;
        conversa.NaoLidasSuporte = 0;
        conversa.NaoLidasUsuario++;
        conversa.UltimaMensagemEm = DateTimeOffset.UtcNow;
        conversa.Mensagens.Add(new MensagemSuporte
        {
            DoSuporte = true,
            Automatica = true,
            Texto = "Atendimento encerrado. Se precisar de mais alguma coisa, é só escrever aqui que a gente continua a conversa."
        });
        await db.SaveChangesAsync(ct);
    }

    // ---------- Comum ----------

    private static string Validar(string? texto)
    {
        texto = texto?.Trim() ?? "";
        if (texto.Length == 0)
            throw new RegraDeNegocioException("Escreva a mensagem.");
        if (texto.Length > 2000)
            throw new RegraDeNegocioException("A mensagem pode ter até 2000 caracteres.");
        return texto;
    }

    private IQueryable<Pedido> PedidosDoUsuario(Usuario usuario) =>
        usuario.Tipo == TipoUsuario.Estabelecimento && usuario.Estabelecimento is { } loja
            ? db.Pedidos.Where(p => p.Oferta.EstabelecimentoId == loja.Id)
            : db.Pedidos.Where(p => p.ClienteId == usuario.Id || p.EntregadorId == usuario.Id);

    private static IQueryable<PedidoAnexoDto> Anexos(IQueryable<Pedido> pedidos) => pedidos.AsNoTracking()
        .Select(p => new PedidoAnexoDto(p.Id, p.Oferta.Estabelecimento.Nome, p.Oferta.Titulo, p.ValorTotal, p.Status, p.TipoEntrega, p.CriadoEm));

    private async Task<IReadOnlyList<MensagemSuporteDto>> MensagensAsync(int conversaId, int? depoisDe, CancellationToken ct) =>
        await db.MensagensSuporte.AsNoTracking()
            .Where(m => m.ConversaId == conversaId && (depoisDe == null || m.Id > depoisDe))
            .OrderBy(m => m.Id)
            .Select(m => new MensagemSuporteDto(m.Id, m.DoSuporte, m.Automatica,
                m.Automatica ? "XEPA" : m.DoSuporte ? NomeEquipe : m.Autor!.Nome, m.Texto, m.CriadoEm,
                m.Pedido == null
                    ? null
                    : new PedidoAnexoDto(m.Pedido.Id, m.Pedido.Oferta.Estabelecimento.Nome, m.Pedido.Oferta.Titulo,
                        m.Pedido.ValorTotal, m.Pedido.Status, m.Pedido.TipoEntrega, m.Pedido.CriadoEm)))
            .ToListAsync(ct);
}
