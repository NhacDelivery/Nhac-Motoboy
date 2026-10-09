import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_provider.dart';
import '../controllers/user_provider.dart';
import '../globals/theme_colors.dart';

class ChatPage extends StatefulWidget {
  final String lojaId, lojaNome;
  const ChatPage({super.key, required this.lojaId, required this.lojaNome});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _provider = ChatProvider();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  String? _submitted;
  int _messageCount = 0;
  Future<void> _abrir() async {
    await _provider.abrir(widget.lojaId);
    if (!mounted) return;
    if (_provider.textoPendente != null) {
      _submitted = _provider.textoPendente;
      _text.text = _submitted!;
    }
  }

  void _atualizar() {
    if (!mounted) return;
    if (_submitted != null && _provider.textoPendente == null) {
      if (_text.text.trim() == _submitted) _text.clear();
      _submitted = null;
    }
    final count = _provider.mensagens.length;
    final nearEnd = !_scroll.hasClients || _scroll.position.extentAfter < 100;
    if (count != _messageCount && (nearEnd || _messageCount == 0)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
    _messageCount = count;
  }

  Future<void> _anteriores() async {
    final height = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    await _provider.carregar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(
          (offset + _scroll.position.maxScrollExtent - height).clamp(
            0.0,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _provider.addListener(_atualizar);
    _abrir();
  }

  @override
  void dispose() {
    _provider.removeListener(_atualizar);
    _provider.dispose();
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _provider,
    builder: (context, _) {
      final p = _provider;
      final id = context.read<UserProvider>().usuarioId;
      return Scaffold(
        backgroundColor: AppColors.fundo,
        appBar: AppBar(
          backgroundColor: AppColors.fundo,
          elevation: 0,
          title: Text(
            widget.lojaNome,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
              fontSize: 17.sp,
              color: AppColors.texto,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (p.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primaria),
                  ),
                ),
              if (!p.connected)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    'Conectando ao chat…',
                    style: AppTextStyles.subtitulo(),
                  ),
                ),
              if (p.erro != null)
                TextButton(
                  onPressed: () => p.tentarNovamente(widget.lojaId),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaria,
                  ),
                  child: Text('${p.erro} Tentar novamente'),
                ),
              if (p.envioSemConfirmacao && p.connected)
                TextButton(
                  onPressed: p.reenviarPendente,
                  child: const Text('Reenviar mensagem pendente'),
                ),
              Expanded(
                child: p.mensagens.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma mensagem. Converse com a loja sobre sua corrida.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitulo(),
                        ),
                      )
                    : ListView(
                        controller: _scroll,
                        padding: EdgeInsets.all(16.r),
                        children: [
                          if (!p.ultima)
                            Center(
                              child: TextButton(
                                onPressed: _anteriores,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaria,
                                ),
                                child: const Text('Mensagens anteriores'),
                              ),
                            ),
                          for (final m in p.mensagens)
                            Align(
                              alignment: m.remetenteUsuarioId == id
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.symmetric(vertical: 4.h),
                                constraints: BoxConstraints(maxWidth: 280.w),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: m.remetenteUsuarioId == id
                                      ? AppColors.primaria
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.conteudo,
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14.sp,
                                        color: AppColors.texto,
                                      ),
                                    ),
                                    Text(
                                      '${m.enviadaEm.toLocal().hour.toString().padLeft(2, '0')}:${m.enviadaEm.toLocal().minute.toString().padLeft(2, '0')} • Enviada',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              if (p.textoPendente != null)
                Text(
                  p.enviando ? 'Enviando…' : 'Envio pendente: tente novamente',
                ),
              Padding(
                padding: EdgeInsets.all(12.r),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('chat-message-input'),
                        enabled: p.textoPendente == null,
                        controller: _text,
                        maxLength: 4000,
                        maxLines: 3,
                        minLines: 1,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14.sp,
                          color: AppColors.texto,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Sua mensagem',
                          filled: true,
                          fillColor: Colors.white,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 10.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primaria,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        key: const Key('chat-send-button'),
                        onPressed: !p.connected || p.enviando
                            ? null
                            : () {
                                final value = _text.text.trim();
                                if (p.enviar(value)) _submitted = value;
                              },
                        icon: Icon(
                          p.enviando
                              ? Icons.hourglass_top_rounded
                              : Icons.send_rounded,
                          color: AppColors.texto,
                          size: 20.r,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
