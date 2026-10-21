/// Validadores dos formulários de login e cadastro.
/// Todos retornam `null` quando o valor é válido (padrão do `FormField`).
class AuthValidadores {
  AuthValidadores._();

  static final _emailRegex = RegExp(r'^[\w.+\-]+@([\w\-]+\.)+[A-Za-z]{2,}$');

  static String _digitos(String v) => v.replaceAll(RegExp(r'\D'), '');

  static String? email(String? v) {
    final valor = (v ?? '').trim();
    if (valor.isEmpty) return 'Digite seu e-mail';
    if (!_emailRegex.hasMatch(valor)) {
      return 'Digite um e-mail válido, como nome@email.com';
    }
    return null;
  }

  static String? senhaLogin(String? v) {
    if (v == null || v.isEmpty) return 'Digite sua senha';
    return null;
  }

  static String? nome(String? v, {required bool restaurante}) {
    final valor = (v ?? '').trim();
    if (restaurante) {
      if (valor.length < 2) return 'Informe o nome do estabelecimento';
      return null;
    }
    final partes = valor.split(RegExp(r'\s+')).where((p) => p.length >= 2);
    if (partes.length < 2) return 'Informe seu nome e sobrenome';
    return null;
  }

  static String? celular(String? v) {
    final d = _digitos(v ?? '');
    if (d.isEmpty) return 'Informe seu celular com DDD';
    if (d.length != 11 || d[2] != '9') {
      return 'Digite um celular válido, como (11) 91234-5678';
    }
    return null;
  }

  static String? cnpj(String? v) {
    final d = _digitos(v ?? '');
    if (d.isEmpty) return 'Informe o CNPJ do estabelecimento';
    if (!_cnpjValido(d)) return 'CNPJ inválido. Confira os 14 números';
    return null;
  }

  static String? senhaCadastro(String? v) {
    if (v == null || v.isEmpty) return 'Crie uma senha';
    if (v.length < 8) return 'Use pelo menos 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Combine letras e números';
    }
    return null;
  }

  static String? confirmarSenha(String? v, String senha) {
    if (v == null || v.isEmpty) return 'Repita a senha';
    if (v != senha) return 'As senhas não são iguais';
    return null;
  }

  /// Validação dos dígitos verificadores do CNPJ.
  static bool _cnpjValido(String d) {
    if (d.length != 14) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(d)) return false;

    int digito(int tamanho) {
      final pesos = tamanho == 12
          ? [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
          : [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      var soma = 0;
      for (var i = 0; i < tamanho; i++) {
        soma += int.parse(d[i]) * pesos[i];
      }
      final resto = soma % 11;
      return resto < 2 ? 0 : 11 - resto;
    }

    return digito(12) == int.parse(d[12]) && digito(13) == int.parse(d[13]);
  }
}