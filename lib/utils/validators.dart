import 'package:email_validator/email_validator.dart';

class Validators {
  static String? validarNome(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório';
    }
    if (value.trim().length < 2) {
      return 'O nome deve ter pelo menos 2 letras';
    }
    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(value)) {
      return 'O nome não pode conter números ou caracteres especiais';
    }
    return null;
  }

  static String? validarEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-mail obrigatório';
    }
    if (!RegExp(r'^[a-zA-Z0-9@.]+$').hasMatch(value.trim())) {
      return 'Caracteres inválidos (use apenas letras, números, @ e ponto)';
    }
    if (!EmailValidator.validate(value.trim())) {
      return 'E-mail inválido';
    }
    return null;
  }

  /// Alinhado com a regra do backend (RegistroRequestDTO): mínimo 8
  /// caracteres, com pelo menos uma letra e um número. Sem isso, o app
  /// deixava o usuário enviar uma senha de 6 caracteres só de números e o
  /// POST /auth/registrar voltava 400 sem nenhuma validação prévia na tela.
  static String? validarSenha(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Senha obrigatória';
    }
    if (value.length < 8) {
      return 'Mínimo de 8 caracteres';
    }
    if (!RegExp(r'^(?=.*[0-9])(?=.*[a-zA-Z]).*$').hasMatch(value)) {
      return 'Use pelo menos uma letra e um número';
    }
    return null;
  }

  static String? validarTelefone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefone obrigatório';
    }
    if (!RegExp(r'^[0-9\s()\-]+$').hasMatch(value)) {
      return 'O telefone não pode conter letras ou caracteres especiais';
    }
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 11) {
      return 'Tamanho inválido (deve ter 10 ou 11 números)';
    }
    return null;
  }

  static String? validarCodigoRecuperacao(String? value) {
    final codigo = value?.trim() ?? '';
    if (codigo.isEmpty) return 'Informe o código';
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      return 'O código deve ter 6 dígitos';
    }
    return null;
  }

  static String? validarSenhaRedefinicao(String? value) {
    if (value == null || value.isEmpty) return 'Informe a nova senha';
    if (value.length < 6) return 'Use pelo menos 6 caracteres';
    return null;
  }

  static String? validarCPF(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'CPF obrigatório';
    }
    final cpf = value.replaceAll(RegExp(r'\D'), '');
    if (cpf.length != 11) {
      return 'O CPF deve ter 11 dígitos';
    }
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
      return 'CPF inválido';
    }
    if (!_validarDigitosCPF(cpf)) {
      return 'CPF inválido';
    }
    return null;
  }

  static bool _validarDigitosCPF(String cpf) {
    List<int> numbers = cpf.split('').map((s) => int.parse(s)).toList();
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += numbers[i] * (10 - i);
    }
    int result = sum % 11;
    int firstDigit = result < 2 ? 0 : 11 - result;
    if (numbers[9] != firstDigit) return false;

    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += numbers[i] * (11 - i);
    }
    result = sum % 11;
    int secondDigit = result < 2 ? 0 : 11 - result;
    if (numbers[10] != secondDigit) return false;

    return true;
  }

  /// Valida CNH (Carteira Nacional de Habilitação)
  /// A CNH deve ter 11 dígitos numéricos
  static String? validarCNH(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'CNH obrigatória';
    }
    final cnh = value.replaceAll(RegExp(r'\D'), '');
    if (cnh.length != 11) {
      return 'A CNH deve ter 11 dígitos';
    }
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cnh)) {
      return 'CNH inválida';
    }
    return null;
  }

  /// Valida placa de veículo no formato brasileiro (antigo e Mercosul)
  /// Antigo: ABC-1234 (3 letras, traço, 4 números)
  /// Mercosul: ABC1C34 (3 letras, 1 número, 1 letra, 2 números)
  static String? validarPlaca(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Placa obrigatória';
    }
    final placa = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    if (placa.length != 7) {
      return 'A placa deve ter 7 caracteres';
    }
    
    // Validação padrão antigo: LLLNNNN (3 letras + 4 números)
    final padraoAntigo = RegExp(r'^[A-Z]{3}[0-9]{4}$');
    // Validação Mercosul: LLNLNLL (letras e números em posições específicas)
    final padraoMercosul = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$');
    
    if (!padraoAntigo.hasMatch(placa) && !padraoMercosul.hasMatch(placa)) {
      return 'Formato de placa inválido';
    }
    
    return null;
  }
}
