import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../components/botoes/botao_largo_nhac.dart';
import '../../components/seta_voltar.dart';
import '../../controllers/cadastro_controller.dart';
import '../../globals/ui_utils.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class ContinuarSenha extends StatefulWidget {
  const ContinuarSenha({super.key});

  @override
  State<ContinuarSenha> createState() {
    return _ContinuarSenhaState();
  }
}

// Alias para compatibilidade de rotas
typedef ContinuarSenhaPage = ContinuarSenha;

class _ContinuarSenhaState extends State<ContinuarSenha> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _senhaVisivel = false;

  final TextEditingController _senhaController = TextEditingController();
  final AuthService _authService = AuthService();

  void _verificarSenha() {
    if (!mounted) {
      return;
    }
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _senhaController.dispose();
    super.dispose();
  }

  /// Antes disto, este botão era 100% decorativo: um delay de 300ms e ia
  /// direto pra home, sem nenhuma chamada ao backend. Qualquer senha, mesmo
  /// errada, "logava com sucesso" — e como o token nunca era setado, toda
  /// chamada de API autenticada depois disso saía sem Authorization.
  Future<void> logar() async {
    final email = context.read<CadastroController>().email;
    final senha = _senhaController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Sessão expirada. Volte e informe o e-mail novamente.');
      return;
    }
    if (senha.isEmpty) {
      setState(() => _errorMessage = 'Digite sua senha.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authService.login(email, senha);
      await ApiConfig.setAuthToken(token);

      if (!mounted) return;
      setState(() => _isLoading = false);

      context.showSuccess('Logado com sucesso!');
      context.go('/home-motoca');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SetaVoltar(),
                      const SizedBox(height: 18.0),
                      const Text(
                        'Bem-vindo Novamente!\nInsira sua senha',
                        style: TextStyle(
                          fontSize: 28.0,
                          color: Color(0xFF5D201C),
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _senhaController,
                          enabled: true,
                          autofocus: true,
                          showCursor: true,
                          obscureText: !_senhaVisivel,
                          obscuringCharacter: '⬤',
                          cursorColor: const Color(0xFFFF6961),
                          style: TextStyle(
                            color: const Color(0xFF5D201C),
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w600,
                            letterSpacing: _senhaVisivel ? 0.0 : 4.0,
                          ),
                          decoration: InputDecoration(
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: _errorMessage != null
                                    ? Colors.red
                                    : Colors.grey,
                                width: 1.0,
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: _errorMessage != null
                                    ? Colors.red
                                    : const Color(0xFFC9BCBC),
                                width: 2.0,
                              ),
                            ),
                            hintText: 'Senha',
                            hintStyle: const TextStyle(
                              color: Color(0xFFC9BCBC),
                              letterSpacing: 0.0,
                            ),
                            suffixIcon: IconButton(
                              icon: _senhaVisivel
                                  ? const Icon(
                                      Icons.visibility,
                                      color: Color(0xFFFF6961),
                                    )
                                  : SvgPicture.asset(
                                      'assets/olho-fechado.svg',
                                      width: 24.0,
                                      height: 24.0,
                                      colorFilter: const ColorFilter.mode(
                                        Color(0xFFC9BCBC),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                              onPressed: () {
                                setState(() {
                                  _senhaVisivel = !_senhaVisivel;
                                });
                              },
                            ),
                          ),
                          onChanged: (value) => _verificarSenha(),
                          onFieldSubmitted: (_) => logar(),
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        height: 50.0,
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            button: true,
                            label: 'Toque para recuperar sua senha',
                            child: GestureDetector(
                              onTap: () {
                                context.push('/recuperar-senha');
                              },
                              child: const Text(
                                'Esqueceu sua senha?',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Color(0xFFFF6961),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40.0,
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            button: true,
                            label: 'Toque para criar uma conta',
                            child: GestureDetector(
                              onTap: () {
                                context.push('/email-motoca');
                              },
                              child: const Text(
                                'Não tem conta? Criar conta',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Color(0xFF5D201C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 21.0,
                right: 21.0,
                bottom: 24.0,
                top: 8.0,
              ),
              child: BotaoLargoNhac(
                texto: 'Continuar',
                onPressed: () => logar(),
                carregando: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
