/// Tipos de conta do Xepa (RF01: clientes e restaurantes).
enum TipoConta { cliente, restaurante }

/// Dados enviados no cadastro (RF01).
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

  Map<String, dynamic> toJson() => {
        'tipo': tipo.name,
        'nome': nome,
        'email': email,
        'celular': celular,
        if (cnpj != null) 'cnpj': cnpj,
        'senha': senha,
      };
}

/// Erro de autenticação com mensagem pronta para exibir ao usuário.
class AuthException implements Exception {
  AuthException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Serviço de autenticação.
///
/// Esta versão é um MOCK para as telas funcionarem sem o backend.
/// Para integrar com a API em C# (RF19/RF20), troque o corpo dos métodos
/// por chamadas HTTP (Dio/http) e guarde o JWT com flutter_secure_storage:
///   - POST /api/auth/login            -> { token }
///   - POST /api/auth/register         -> { token }
///   - POST /api/auth/forgot-password
///
/// Para testar os estados de erro no mock:
///   - login com `erro@xepa.com`        -> credenciais inválidas
///   - cadastro com `existente@xepa.com` -> e-mail já cadastrado
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  Future<void> login({required String email, required String senha}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (email == 'erro@xepa.com') {
      throw AuthException(
        'E-mail ou senha incorretos. Confira os dados e tente de novo.',
      );
    }
  }

  Future<void> cadastrar(CadastroDados dados) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (dados.email == 'existente@xepa.com') {
      throw AuthException(
        'Já existe uma conta com este e-mail. Entre na sua conta ou use outro e-mail.',
      );
    }
  }

  Future<void> recuperarSenha({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }
}