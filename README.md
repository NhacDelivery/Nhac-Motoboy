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
- O indicador de frete é a taxa bruta calculada para pedidos entregues; a API ainda não expõe repasses, valor devido ou pagamentos efetivados.
- As preferências de notificações são salvas na conta, mas ainda não há push em segundo plano. O sino mostra ofertas e atualizações recebidas enquanto o aplicativo está aberto.
- A confirmação e a repetição idempotente de mensagens dependem do suporte a `clientMessageId` no backend. Publique a alteração correspondente no backend antes de usar o novo chat.
- A foto é enviada ao endpoint autenticado `/api/v1/uploads/imagem` e vinculada a `imagemUrl` do usuário. A configuração de storage do backend deve estar ativa.
- Não há API de suporte ou retirada de corrida após o aceite. A tela orienta o motoboy a conversar com a loja; nenhuma corrida é liberada automaticamente.

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
de produção. O CI fixa o commit do backend, registrado também nos logs.

| Cenário | Verificação |
| --- | --- |
| IT-MOTO-001 | Login JWT, cadastro de entregador, localização, ONLINE, despacho real, aceite mantendo PREPARANDO, rota, coleta para SAIU_ENTREGA, recuperação da entrega, localização visível ao cliente, erro na tela de código, código `0123`, ENTREGUE, histórico sem duplicata, avaliação real na tela e logout OFFLINE. |
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
