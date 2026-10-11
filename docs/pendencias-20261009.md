# Correções e validação de 09/10/2026

O CI agora testa contra `feature/chat-clientes-20261008` do backend integrado. Foram corrigidos: destinatário obrigatório antes de abrir push; seleção imediata da oferta indicada; push inicializado também no iOS, com App ID e bundle próprios; recebimento remoto nos entitlements; Google Client ID no build iOS; bloqueio do login por telefone durante e-mail/Google; reenvio de SMS na troca do telefone; chat bloqueia edição do envio pendente e confere sucesso do armazenamento antes de enviar; suporte mantém protocolo e payload em armazenamento, bloqueia mudanças enquanto o resultado for incerto e permite acompanhar pelo histórico.

O atendimento pode efetivamente retirar ou transferir a corrida pelo endpoint ADMIN do backend. O motoboy permanece responsável até a confirmação, especialmente após coleta.

## Configurações necessárias

GitHub Variables: `GOOGLE_WEB_CLIENT_ID`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID` (Android), `FIREBASE_IOS_APP_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`. O bundle iOS atual é `com.example.nhacMotoboy`; registrar exatamente esse bundle no Firebase e no Apple Developer. Autorizar o SHA-1/SHA-256 do APK realmente instalado para Google. Não reutilizar App IDs de outro aplicativo. O workflow registra no resumo quando o APK foi construído sem configuração completa de push.

No backend, configurar conta de serviço Firebase e publicar a branch integrada no ambiente usado pelo aplicativo. No Firebase, habilitar APNs com a equipe Apple correta e assinar o iOS com Push Notifications e Background Modes. Build sem codesign não comprova entrega push no aparelho.

A regra continua colocando o entregador offline quando sai do app, preservando corrida ativa. Mensagens e atendimentos podem gerar push conforme preferências; novas ofertas dependem de disponibilidade online válida e um aviso antigo pode já ter expirado ao ser aberto.

## Evidência local e aceitação em aparelho

87 testes Flutter passaram e a análise não apresentou problemas usando Flutter 3.47.6, a versão do CI. O teste de backend real da suíte padrão é ignorado quando não há servidor isolado; não é uma validação de produção.

Ainda executar no aparelho/emulador: negar e conceder permissões; selecionar/cancelar Google e testar falha de rede; receber SMS real e reenviar; receber push em primeiro plano, segundo plano e após encerramento; trocar conta e tocar no push anterior; perder a confirmação de chat/suporte, encerrar processo e recuperar exatamente o envio; reconectar socket; abrir navegação externa, bloquear tela e conferir continuidade do GPS no iPhone; comparar rota/estimativa real de bicicleta com o servidor configurado. Este ambiente não dispõe de emulador, iPhone ou credenciais para comprovar esses casos.

Para backend isolado, usar `BACKEND_DIR` apontando a branch integrada e `tool/run_integration.sh`; para o teste já existente de dispositivo, usar `RUN_DEVICE=true DEVICE_ID=emulator-5554`. Nenhum teste de envio utiliza o backend de produção.
