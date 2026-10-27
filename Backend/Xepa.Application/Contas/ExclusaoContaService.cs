using System.ComponentModel.DataAnnotations;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using Xepa.Domain;
using Xepa.Domain.Entities;

namespace Xepa.Application.Contas;

public class ExcluirContaRequest
{
    /// <summary>Senha atual. Dispensada para conta criada pelo Google (que nunca teve senha própria).</summary>
    [MaxLength(100)]
    public string? Senha { get; init; }

    /// <summary>O usuário digita EXCLUIR para confirmar que entendeu que não dá para desfazer.</summary>
    [Required(ErrorMessage = "Digite EXCLUIR para confirmar.")]
    public required string Confirmacao { get; init; }
}

/// <summary>
/// Exclusão da conta a pedido do titular (LGPD, art. 18, VI). Os dados pessoais são apagados ou anonimizados; os pedidos
/// ficam no histórico das lojas e da contabilidade sem identificar a pessoa (art. 16, I: obrigação legal e fiscal).
/// </summary>
public class ExclusaoContaService(IXepaDb db, IHasherSenha hasher)
{
    private static readonly StatusPedido[] Encerrados = [StatusPedido.Entregue, StatusPedido.Cancelado, StatusPedido.AguardandoPagamento];

    public async Task ExcluirAsync(int usuarioId, ExcluirContaRequest request, CancellationToken ct)
    {
        var usuario = await db.Usuarios.FirstOrDefaultAsync(u => u.Id == usuarioId, ct)
                      ?? throw new NaoEncontradoException("Usuário não encontrado.");
        if (usuario.Tipo is not (TipoUsuario.Cliente or TipoUsuario.Entregador))
            throw new RegraDeNegocioException("Contas de loja e da administração são encerradas pelo suporte da XEPA.");
        if (!string.Equals(request.Confirmacao.Trim(), "EXCLUIR", StringComparison.OrdinalIgnoreCase))
            throw new RegraDeNegocioException("Digite EXCLUIR para confirmar.");
        if (usuario.GoogleId is null || !string.IsNullOrEmpty(request.Senha))
        {
            if (string.IsNullOrEmpty(request.Senha) || !hasher.Conferir(usuario, request.Senha))
                throw new RegraDeNegocioException("A senha não confere.");
        }

        if (await db.Pedidos.AnyAsync(p => (p.ClienteId == usuarioId || p.EntregadorId == usuarioId) && !Encerrados.Contains(p.Status), ct))
            throw new RegraDeNegocioException("Você tem um pedido ou uma entrega em andamento. Espere terminar para excluir a conta.");

        var aReceber = await db.Pedidos
            .Where(p => p.EntregadorId == usuarioId && p.Status == StatusPedido.Entregue
                        && (p.RepasseEntregadorId == null || p.RepasseEntregador!.PagoEm == null))
            .SumAsync(p => (decimal?)p.TaxaEntrega, ct) ?? 0;
        if (aReceber > 0)
            throw new RegraDeNegocioException(
                $"Você ainda tem {aReceber.ToString("C", System.Globalization.CultureInfo.GetCultureInfo("pt-BR"))} de entregas a receber. Espere o repasse cair para excluir a conta.");

        // Dados ligados à conta que não precisam ficar: endereços salvos, favoritos, sessões, códigos e o chat de suporte.
        db.Enderecos.RemoveRange(await db.Enderecos.Where(e => e.UsuarioId == usuarioId).ToListAsync(ct));
        db.Favoritos.RemoveRange(await db.Favoritos.Where(f => f.UsuarioId == usuarioId).ToListAsync(ct));
        db.TokensRenovacao.RemoveRange(await db.TokensRenovacao.Where(t => t.UsuarioId == usuarioId).ToListAsync(ct));
        db.CodigosRecuperacao.RemoveRange(await db.CodigosRecuperacao.Where(c => c.UsuarioId == usuarioId).ToListAsync(ct));
        db.ConversasSuporte.RemoveRange(await db.ConversasSuporte.Where(c => c.UsuarioId == usuarioId).ToListAsync(ct));
        db.DispositivosPush.RemoveRange(await db.DispositivosPush.Where(d => d.UsuarioId == usuarioId).ToListAsync(ct));

        // O registro fica (os pedidos apontam para ele), mas sem nada que identifique a pessoa e sem como entrar.
        usuario.Nome = "Conta excluída";
        usuario.Email = $"excluida-{usuario.Id}@xepa.invalid";
        usuario.SenhaHash = hasher.Gerar(usuario, Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)));
        usuario.Telefone = null;
        usuario.GoogleId = null;
        usuario.Placa = null;
        usuario.ModeloMoto = null;
        usuario.Online = false;
        usuario.Bloqueado = true;
        usuario.ExcluidaEm = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);
    }
}
