import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../components/home/nhac_bottom_nav_bar.dart';
import '../../components/home/status_toggle_button.dart';
import '../../controllers/entrega_provider.dart';
import '../../controllers/user_provider.dart';
import '../../globals/theme_colors.dart';
import 'tabs/ganhos_tab.dart';
import 'tabs/motoboy_inicio.dart';
import 'tabs/pedidos_tab.dart';
import 'tabs/perfil_tab.dart';

class HomeMotocaPage extends StatefulWidget {
  const HomeMotocaPage({super.key});
  @override
  State<HomeMotocaPage> createState() => _HomeMotocaPageState();
}

class _HomeMotocaPageState extends State<HomeMotocaPage> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserProvider>().carregarDadosReais();
      context.read<EntregaProvider>().sincronizar();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 350), curve: Curves.fastOutSlowIn);
  }

  Future<void> _alterarStatusOnline(bool online) async {
    final entrega = context.read<EntregaProvider>();
    if (entrega.isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aguarde a sincronização terminar e tente novamente.'),
      ));
      return;
    }
    await entrega.alternarStatusOnline(online);
    if (!mounted || entrega.estaOnline == online || entrega.emEntrega) return;
    final mensagem = entrega.erroLocalizacao ?? entrega.erro ??
        'Não foi possível confirmar sua disponibilidade. Tente novamente.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensagem),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final entrega = context.watch<EntregaProvider>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.fundo,
      extendBody: true,
      appBar: _selectedIndex == 3 ? null : AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.fundo,
        title: Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: IgnorePointer(
            ignoring: !entrega.cadastroAtivo || entrega.emEntrega || entrega.isLoading,
            child: StatusToggleButton(
              estaOnline: entrega.estaOnline,
              carregando: entrega.isChangingStatus,
              onChanged: _alterarStatusOnline,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            icon: Icon(Icons.logout_rounded, color: AppColors.texto, size: 24.r),
            onPressed: entrega.sair,
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Stack(children: [
        PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: [
            MotoboyInicio(onToggleOnline: _alterarStatusOnline),
            const PedidosTab(),
            const GanhosTab(),
            const PerfilTab(),
          ],
        ),
        Positioned(
          bottom: bottomPadding + 16.h,
          left: 20.w,
          right: 20.w,
          child: NhacBottomNavBar(
            selectedIndex: _selectedIndex,
            onItemSelected: _onItemTapped,
          ),
        ),
      ]),
    );
  }
}
