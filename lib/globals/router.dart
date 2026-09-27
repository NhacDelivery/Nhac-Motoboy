import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_config.dart';
import '../pages/auth/continuar_senha.dart';
import '../pages/auth/criar_conta_codigo.dart';
import '../pages/auth/criar_conta_dados.dart';
import '../pages/auth/insira_telefone.dart';
import '../pages/auth/verificacao_numero.dart';
import '../pages/auth/recuperar_senha_page.dart';
import '../pages/bem_vindo_motoca.dart';
import '../pages/cadastro_motoboy_page.dart';
import '../pages/email_motoca.dart';
import '../pages/home/home_motoca_page.dart';
import '../pages/home/tabs/profile/editar_email_page.dart';
import '../pages/home/tabs/profile/editar_foto_page.dart';
import '../pages/home/tabs/profile/editar_veiculo_page.dart';
import '../pages/home/tabs/profile/editar_documentos_page.dart';
import '../pages/home/tabs/profile/editar_dados_bancarios_page.dart';
import '../pages/home/tabs/profile/notificacoes_page.dart';
import '../pages/home/tabs/profile/editar_nome_page.dart';
import '../pages/home/tabs/profile/editar_senha_page.dart';
import '../pages/home/tabs/profile/editar_telefone_page.dart';
import '../pages/home/tabs/rota_entrega_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: ApiConfig.session,
  redirect: (context, state) {
    const public = {'/', '/email-motoca', '/continuar-senha', '/criar-conta-codigo',
      '/criar-conta-dados', '/insira-telefone', '/verificacao-numero', '/recuperar-senha'};
    final entry = public.contains(state.matchedLocation);
    if (!ApiConfig.temSessaoSalva && !entry) return '/';
    if (ApiConfig.temSessaoSalva && entry) return '/home-motoca';
    return null;
  },
  errorBuilder: (context, state) => Scaffold(body: Center(child: TextButton(
    onPressed: () => context.go('/'), child: const Text('Página indisponível. Voltar ao início')))),
  routes: [
    GoRoute(path: '/', builder: (_, _) => const BemVindoMotoca()),
    GoRoute(path: '/email-motoca', builder: (_, _) => const EmailMotocaPage()),
    GoRoute(path: '/continuar-senha', builder: (_, _) => const ContinuarSenhaPage()),
    GoRoute(path: '/criar-conta-codigo', builder: (_, _) => const CriarContaCodigoPage()),
    GoRoute(path: '/criar-conta-dados', builder: (_, _) => const CriarContaDadosPage()),
    GoRoute(path: '/insira-telefone', builder: (_, _) => const InsiraTelefonePage()),
    GoRoute(path: '/verificacao-numero', builder: (_, _) => const VerificacaoNumeroPage()),
    GoRoute(path: '/recuperar-senha', builder: (_, _) => const RecuperarSenhaPage()),
    GoRoute(path: '/home-motoca', builder: (_, _) => const HomeMotocaPage()),
    GoRoute(path: '/home-page', redirect: (_, _) => '/home-motoca'),
    GoRoute(path: '/editar-nome', builder: (_, _) => const EditarNomePage()),
    GoRoute(path: '/editar-email', builder: (_, _) => const EditarEmailPage()),
    GoRoute(path: '/editar-foto', builder: (_, _) => const EditarFotoPage()),
    GoRoute(path: '/editar-veiculo', builder: (_, _) => const EditarVeiculoPage()),
    GoRoute(path: '/editar-documentos', builder: (_, _) => const EditarDocumentosPage()),
    GoRoute(path: '/editar-dados-bancarios', builder: (_, _) => const EditarDadosBancariosPage()),
    GoRoute(path: '/notificacoes', builder: (_, _) => const NotificacoesPage()),
    GoRoute(path: '/editar-telefone', builder: (_, _) => const EditarTelefonePage()),
    GoRoute(path: '/editar-senha', builder: (_, _) => const EditarSenhaPage()),
    GoRoute(path: '/rota-entrega', builder: (_, _) => const RotaEntregaPage()),
    GoRoute(path: '/cadastro-motoboy', builder: (_, _) => const CadastroMotoboyPage()),
  ],
);
