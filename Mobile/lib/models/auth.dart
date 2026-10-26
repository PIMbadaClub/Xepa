import '../api/api.dart';
import '../api/tempo_real.dart';

/// Tipos de conta escolhidos na tela de cadastro.
enum TipoConta { cliente, restaurante }

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
  });

  final TipoConta tipo;

  /// Nome completo (cliente) ou nome do estabelecimento (restaurante).
  final String nome;
  final String email;

  /// Somente dígitos, com DDD. Ex.: 11912345678
  final String celular;

  /// Somente dígitos. Preenchido apenas para restaurantes.
  final String? cnpj;
  final String senha;
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
      return _usuario;
    } on ApiException {
      await Api.instance.limparSessao();
      return null;
    }
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
      });
      return await _abrir(sessao);
    } on ApiException catch (e) {
      throw AuthException(e.mensagem);
    }
  }

  /// Ainda sem endpoint na API: a recuperação de senha entra numa próxima sprint.
  Future<void> recuperarSenha({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> sair() async {
    final renovacao = await Api.instance.tokenRenovacao();
    if (renovacao != null) {
      try {
        await Api.instance.post<void>('/api/auth/sair', {'tokenRenovacao': renovacao});
      } on ApiException {
        // Mesmo offline o app esquece a sessão local.
      }
    }
    await TempoReal.instance.desconectar();
    await Api.instance.limparSessao();
    _usuario = null;
  }

  Future<Usuario> _abrir(Map<String, dynamic> sessao) async {
    await Api.instance.salvarSessao(sessao);
    return _usuario = Usuario.fromJson(sessao['usuario'] as Map<String, dynamic>);
  }
}
