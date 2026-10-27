import '../api/cidade.dart';
import '../api/modo.dart';
import '../api/favoritos.dart';
import '../api/notificacoes.dart';
import '../api/api.dart';
import '../api/push.dart';
import '../api/tempo_real.dart';

/// Tipos de conta escolhidos na tela de cadastro.
enum TipoConta { cliente, restaurante, entregador }

/// Perfil do usuário logado, como a API devolve.
enum PerfilUsuario { cliente, estabelecimento, entregador, administrador }

class Usuario {
  const Usuario({required this.id, required this.nome, required this.email, this.telefone, required this.perfil});

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: j['id'] as int,
        nome: j['nome'] as String,
        email: j['email'] as String,
        telefone: j['telefone'] as String?,
        perfil: PerfilUsuario.values.byName(_minuscula(j['tipo'] as String)),
      );

  final int id;
  final String nome;
  final String email;
  final String? telefone;
  final PerfilUsuario perfil;

  String get primeiroNome => nome.split(' ').first;

  static String _minuscula(String s) => s[0].toLowerCase() + s.substring(1);
}

/// Dados enviados no cadastro.
class CadastroDados {
  const CadastroDados({
    required this.tipo,
    required this.nome,
    required this.email,
    required this.celular,
    required this.senha,
    this.cnpj,
    this.placa,
    this.aceitouTermos = false,
  });

  final TipoConta tipo;

  /// Nome completo (cliente) ou nome do estabelecimento (restaurante).
  final String nome;
  final String email;

  /// Somente dígitos, com DDD. Ex.: 11912345678
  final String celular;

  /// Somente dígitos. Preenchido apenas para restaurantes.
  final String? cnpj;

  /// Placa da moto, só para entregador (ex.: ABC1D23).
  final String? placa;
  final String senha;

  /// Marcou "Li e aceito os termos de uso e a política de privacidade" (LGPD).
  final bool aceitouTermos;
}

/// Erro de autenticação com mensagem pronta para exibir ao usuário.
class AuthException implements Exception {
  AuthException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Login, cadastro e sessão, integrados à API (/api/auth). O JWT fica no armazenamento seguro.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  Usuario? _usuario;
  Usuario? get usuario => _usuario;

  /// Ao abrir o app: se há sessão salva, confirma com a API (renovando o token se preciso).
  Future<Usuario?> restaurarSessao() async {
    if (await Api.instance.tokenAcesso() == null) return null;
    try {
      _usuario = Usuario.fromJson(await Api.instance.get<Map<String, dynamic>>('/api/usuarios/me'));
      Push.instance.registrar();
      return _usuario;
    } on ApiException {
      await Api.instance.limparSessao();
      return null;
    }
  }

  /// Salva nome e telefone; o usuário em memória passa a refletir o que a API devolveu.
  Future<Usuario> atualizarPerfil({required String nome, String? telefone}) async {
    final j = await Api.instance.put<Map<String, dynamic>>('/api/usuarios/me', {'nome': nome, 'telefone': telefone});
    return _usuario = Usuario.fromJson(j);
  }

  /// Troca a senha mantendo esta sessão (as outras são encerradas pela API).
  Future<void> alterarSenha({required String atual, required String nova}) async {
    await Api.instance.post<void>(
      '/api/usuarios/me/senha',
      {'senhaAtual': atual, 'novaSenha': nova},
      {'X-Token-Renovacao': await Api.instance.tokenRenovacao()},
    );
  }

  Future<Usuario> login({required String email, required String senha}) async {
    try {
      final sessao = await Api.instance.post<Map<String, dynamic>>('/api/auth/login', {'email': email, 'senha': senha});
      return await _abrir(sessao);
    } on ApiException catch (e) {
      throw AuthException(e.status == 401
          ? 'E-mail ou senha incorretos. Confira os dados e tente de novo.'
          : e.mensagem);
    }
  }

  Future<Usuario> cadastrar(CadastroDados dados) async {
    if (dados.tipo == TipoConta.restaurante) {
      throw AuthException(
        'Lojas se cadastram pelo portal do estabelecimento, onde o CNPJ é conferido antes da aprovação.',
      );
    }
    try {
      final sessao = await Api.instance.post<Map<String, dynamic>>('/api/auth/registrar', {
        'nome': dados.nome,
        'email': dados.email,
        'senha': dados.senha,
        'telefone': dados.celular,
        'tipo': dados.tipo == TipoConta.entregador ? 'Entregador' : 'Cliente',
        'aceitouTermos': dados.aceitouTermos,
        if (dados.tipo == TipoConta.entregador) 'placa': dados.placa,
      });
      return await _abrir(sessao);
    } on ApiException catch (e) {
      throw AuthException(e.mensagem);
    }
  }

  /// Endereço que começa o "Continuar com Google" (a API leva ao Google e volta ao app com ?google=código).
  String urlLoginGoogle(String retorno) => '$apiUrl/api/auth/google?retorno=${Uri.encodeQueryComponent(retorno)}';

  /// Troca o código de uso único que voltou do Google pela sessão do app.
  Future<Usuario> entrarComGoogle(String codigo) async {
    try {
      final sessao = await Api.instance.post<Map<String, dynamic>>('/api/auth/google/sessao', {'codigo': codigo});
      return await _abrir(sessao);
    } on ApiException catch (e) {
      throw AuthException(e.mensagem);
    }
  }

  /// Pede o código de 6 dígitos por e-mail. A API responde igual exista ou não a conta.
  Future<void> recuperarSenha({required String email}) async {
    try {
      await Api.instance.post<void>('/api/auth/recuperar-senha', {'email': email});
    } on ApiException catch (e) {
      throw AuthException(e.status == 429 ? 'Muitas tentativas. Espere um minuto e tente de novo.' : e.mensagem);
    }
  }

  /// Troca a senha com o código do e-mail; a API já devolve a sessão aberta.
  Future<Usuario> redefinirSenha({required String email, required String codigo, required String novaSenha}) async {
    try {
      final sessao = await Api.instance.post<Map<String, dynamic>>(
          '/api/auth/redefinir-senha', {'email': email, 'codigo': codigo, 'novaSenha': novaSenha});
      return await _abrir(sessao);
    } on ApiException catch (e) {
      throw AuthException(e.status == 429 ? 'Muitas tentativas. Espere um minuto e tente de novo.' : e.mensagem);
    }
  }

  /// Exclui a conta (LGPD) e limpa a sessão local. A senha é dispensada para conta criada pelo Google.
  Future<void> excluirConta({String? senha}) async {
    try {
      await Api.instance.post<void>('/api/usuarios/me/excluir', {'senha': senha, 'confirmacao': 'EXCLUIR'});
    } on ApiException catch (e) {
      throw AuthException(e.mensagem);
    }
    await _encerrarLocal();
  }

  Future<void> sair() async {
    await Push.instance.remover();
    final renovacao = await Api.instance.tokenRenovacao();
    if (renovacao != null) {
      try {
        await Api.instance.post<void>('/api/auth/sair', {'tokenRenovacao': renovacao});
      } on ApiException {
        // Mesmo offline o app esquece a sessão local.
      }
    }
    await _encerrarLocal();
  }

  Future<void> _encerrarLocal() async {
    Notificacoes.instance.parar();
    PedidosAtivos.instance.parar();
    Favoritos.instance.limpar();
    CidadeCliente.instance.limpar();
    await ModoApp.definir(cliente: false);
    await TempoReal.instance.desconectar();
    await Api.instance.limparSessao();
    _usuario = null;
  }

  Future<Usuario> _abrir(Map<String, dynamic> sessao) async {
    await Api.instance.salvarSessao(sessao);
    _usuario = Usuario.fromJson(sessao['usuario'] as Map<String, dynamic>);
    Push.instance.registrar();
    return _usuario!;
  }
}
