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

  @override
  void initState() {
    super.initState();
    _provider.abrir(widget.lojaId);
  }

  @override
  void dispose() {
    _provider.dispose();
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
              title: Text(widget.lojaNome,
                  style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 17.sp, color: AppColors.texto)),
            ),
            body: SafeArea(
              child: Column(children: [
                if (p.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaria)),
                  ),
                if (!p.connected)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text('Conectando ao chat…', style: AppTextStyles.subtitulo()),
                  ),
                if (p.erro != null)
                  TextButton(
                    onPressed: () => p.conversaId == null ? p.abrir(widget.lojaId) : p.carregar(reset: true),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaria),
                    child: Text('${p.erro} Tentar novamente'),
                  ),
                Expanded(
                  child: p.mensagens.isEmpty
                      ? Center(
                          child: Text('Nenhuma mensagem. Converse com a loja sobre sua corrida.',
                              textAlign: TextAlign.center, style: AppTextStyles.subtitulo()),
                        )
                      : ListView(
                          padding: EdgeInsets.all(16.r),
                          children: [
                            if (!p.ultima)
                              Center(
                                child: TextButton(
                                  onPressed: p.carregar,
                                  style: TextButton.styleFrom(foregroundColor: AppColors.primaria),
                                  child: const Text('Mensagens anteriores'),
                                ),
                              ),
                            for (final m in p.mensagens)
                              Align(
                                alignment: m.remetenteUsuarioId == id ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: EdgeInsets.symmetric(vertical: 4.h),
                                  constraints: BoxConstraints(maxWidth: 280.w),
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: m.remetenteUsuarioId == id ? AppColors.primaria : Colors.white,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Text(
                                    m.conteudo,
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14.sp,
                                      color: m.remetenteUsuarioId == id ? Colors.white : AppColors.texto,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: EdgeInsets.all(12.r),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        key: const Key('chat-message-input'),
                        controller: _text,
                        maxLength: 4000,
                        maxLines: 3,
                        minLines: 1,
                        style: TextStyle(fontFamily: 'Roboto', fontSize: 14.sp, color: AppColors.texto),
                        decoration: InputDecoration(
                          hintText: 'Sua mensagem',
                          filled: true,
                          fillColor: Colors.white,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      decoration: const BoxDecoration(color: AppColors.primaria, shape: BoxShape.circle),
                      child: IconButton(
                        key: const Key('chat-send-button'),
                        onPressed: !p.connected || p.enviando
                            ? null
                            : () {
                                if (p.enviar(_text.text)) _text.clear();
                              },
                        icon: Icon(p.enviando ? Icons.hourglass_top_rounded : Icons.send_rounded, color: Colors.white, size: 20.r),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}
