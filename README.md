# Nhac Motoboy

Aplicativo Flutter para entregadores do ecossistema Nhac. Permite ficar disponível, receber e aceitar ofertas, acompanhar a rota, confirmar retirada e conclusão com o código do cliente, consultar avaliações, conversar com a loja e consultar histórico e frete calculado.

## Executar

Requer Flutter compatível com Dart 3.11.5 ou superior. A URL padrão de API e WebSocket é `https://backend-nhac.onrender.com`; para usar produção, execute `flutter run` sem substituir `API_BASE_URL`. Em desenvolvimento local:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

No Android Emulator, `10.0.2.2` aponta para o computador que executa o backend. Em dispositivo físico, use o IP alcançável pelo aparelho.

## Login Google

A API aceita o token de identidade em `POST /api/v1/auth/social`. O aplicativo usa `google_sign_in` e envia o token à API; não usa o token de acesso do Google como sessão Nhac.

Registre o aplicativo Android e os certificados de assinatura de desenvolvimento/produção no provedor OAuth. Crie um cliente OAuth do tipo Web aceito pelo `google.client.id` do backend e compile com o mesmo ID:

```bash
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=seu-client-id-web.apps.googleusercontent.com
```

A integração nativa de iOS requer também o registro do aplicativo e o esquema de URL reverso no `Info.plist`. Essas credenciais e registros não fazem parte do repositório; sem eles, o login Google não pode autenticar no aparelho.

## Fluxos atualizados para a main do backend

- Depois da retirada, a confirmação abre uma tela para o código de quatro dígitos fornecido pelo cliente. O app envia `{codigo}` ao concluir e mostra tentativas restantes ou o horário de desbloqueio informado pelo servidor.
- Perfil → Minhas avaliações consulta `/api/v1/entregador/avaliacoes`, com resumo real, paginação e recuperação de falhas.
- A tela da corrida permite ligar para o cliente quando a API retorna telefone.
- Os eventos em tempo real são acompanhados de consultas de recuperação a cada 30 s com socket conectado, 10 s sem socket e 60 s offline. GPS continua a cada 30 s; precisão média esperando ofertas e alta durante uma corrida. O contador reconstrói somente o cartão de oferta.
- As dependências sem referências em `lib` (`nowa_runtime`, `lottie` e a dependência direta `path_provider`) foram removidas; os plugins nativos foram regenerados.

## Contratos importantes

- O prazo de uma oferta é definido por `expiraEm` no backend (90 segundos no despacho atual).
- O status offline ao ir para segundo plano é tentado novamente enquanto o processo está vivo. Caso o sistema operacional encerre o app ou a rede continue indisponível, a confirmação não é garantida. O backend filtra posições antigas no despacho.
- O indicador de frete é a taxa bruta calculada. O extrato de repasses consulta valores devidos, pagos e status em `/api/v1/entregador/repasses`; valores não apurados não são tratados como zero.
- As preferências são salvas na conta. Push usa Firebase quando as credenciais da plataforma estão configuradas; notificações são verificadas por destinatário antes de abrir oferta, chat ou aviso.
- O chat com a loja usa `clientMessageId` para confirmar e repetir mensagens sem duplicar, conforme a main atual. Uma falha ao abrir outra loja limpa a conversa ativa e a tentativa seguinte reabre a loja solicitada.
- A foto é enviada ao endpoint autenticado `/api/v1/uploads/imagem` e vinculada a `imagemUrl` do usuário. A configuração de storage do backend deve estar ativa.
- Suporte abre e acompanha protocolos em `/api/v1/entregas/{pedidoId}/suporte`. Retirada e transferência são decididas pelo backend; o app recupera o estado por `/api/v1/entregador/estado`.

## Verificação

```bash
flutter analyze
flutter test
flutter build apk --debug
```

A identidade visual e as regras de estado das telas estão em [DESIGN.md](DESIGN.md) e [UX-CONTRACT.md](UX-CONTRACT.md).


## Integração com o backend real

Execute `BACKEND_DIR=../backend-nhac bash tool/run_integration.sh` com Java 25 e
Flutter 3.47.6 no PATH. O runner sobe o Spring Boot em `127.0.0.1:18080`, cria um
H2 descartável e encerra o processo ao terminar. Não exige Docker ou credenciais
de produção. O CI usa a main do backend; o SHA exato de cada execução é registrado nos logs.

| Cenário | Verificação |
| --- | --- |
| IT-MOTO-001 | Login JWT, cadastro de entregador, localização, ONLINE, despacho real, aceite mantendo PREPARANDO, rota, coleta para SAIU_ENTREGA recuperada após perda da resposta, troca da rota para o cliente, recuperação da entrega, localização visível ao cliente, erro na tela de código, código `0123`, ENTREGUE, histórico sem duplicata, avaliação real na tela e logout OFFLINE. |
| IT-MOTO-002 | Contador persistido entre requisições, bloqueio após cinco códigos errados, tela desabilitada, código correto recusado durante o bloqueio e entrega mantida em andamento. |
| IT-MOTO-003 | Conta sem vínculo de entregador não consulta ofertas nem a rota de outra pessoa. |

HTTP, JWT, providers, telas, serviços Spring e persistência são reais. Apenas a
leitura do GPS e SharedPreferences usam adaptadores controlados no host. O
provedor externo de rota usa o modo de teste existente do backend. Aquisição do
GPS no Android, telefonia, tiles do mapa, WebSocket e retomada do processo nativo
precisam de testes em emulador/aparelho; esta suíte não afirma cobri-los.

Os pedidos PREPARANDO são fixtures: criação, pagamento e preparação pelo lojista
ficam fora deste recorte. Cada execução inicia um banco novo; não depende de uma
execução anterior. A suíte é opt-in (`RUN_INTEGRATION=true`) e recusa URL que não
seja loopback. `flutter test` comum apenas a marca como ignorada.

Logs: `integration-logs/backend-build.log`, `backend.log`, `flutter.log` e
`backend-sha.txt`. No GitHub ficam no artefato `motoboy-integration-logs`.

A revisão de 11/10/2026 usou a main `62fe4325c8d3244898a60fff842e6f463c2885a9`.
As correções de tentativas de código, estado consolidado, chat, suporte e repasses
já fazem parte dela. Para reproduzir essa revisão, use esse SHA; no CI, consulte
`backend-sha.txt` para identificar a versão testada.

### Otimizações de consultas e rastreamento

O app usa `GET /api/v1/entregador/estado` sem cache para sincronizar perfil, corrida e ofertas em uma chamada. Servidores anteriores mantêm compatibilidade pelas consultas individuais. As suítes de integração e dispositivo acompanham a main do backend.

Frete e histórico têm cache de sessão de 45 s; avaliações, 1 min; perfil de exibição, 3 min. O cache é limitado, somente em memória, limpo na troca de conta/logout e invalidado após conclusão. Atualização manual ignora TTL. Corridas, ofertas e códigos não são usados como autoridade em cache. A rota é invalidada ao mudar o pedido, a etapa ou as coordenadas; respostas de uma etapa anterior não sobrescrevem a rota vigente.

No Android, o GPS durante corrida usa o stream do geolocator com serviço de localização e notificação. Abrir Maps preserva esse stream; finalizar encerra rastreamento. Encerrar o processo não reinicia o serviço. Teste automatizado valida o ciclo de vida do provider; validação em aparelho com GPS, Maps e economia de bateria permanece necessária. iOS/web mantêm atualização em primeiro plano.

Histórico oferece filtros por status e construção de cards sob demanda. Frete mantém dados do mesmo período em falha e usa valores em pt_BR. Testes novos cobrem cache, troca de conta, edição concorrente, GPS pausado e telas em 320 px com texto ampliado.
