# Integração do Motoboy com o backend da main

Execute com Flutter 3.47.6, Java 25 e um checkout atualizado do backend:

```bash
flutter pub get
BACKEND_DIR=/caminho/backend-nhac bash tool/run_integration.sh
```

O runner compila a main, inicia Spring Boot em `127.0.0.1:18080` com H2 em memória, executa todos os arquivos de `test/integration/` sequencialmente e encerra o servidor, mesmo se algum teste falhar. O workflow `Flutter CI` repete a execução e guarda os logs e SHA do backend no artefato `motoboy-integration-logs`. A suíte padrão `flutter test` ignora os dois arquivos de integração quando `RUN_INTEGRATION` não está habilitado.

## Matriz de cobertura automatizada

Os identificadores abaixo aparecem no log. Há asserções do resultado e da persistência; respostas de sucesso da API não são simuladas. Os três cenários originais incluem a tela de confirmação e a consulta de avaliação feita pelo cliente.

| Fluxo | Cenários | Verificações |
| --- | --- | --- |
| Conta por e-mail | 004, 028 | Código emitido pelo backend, confirmação, cadastro, e-mail existente, duplicidade, senha inválida e origem do aplicativo |
| Senha | 005 | Recuperação, código consumido, alteração e rejeição da senha anterior |
| SMS e telefone | 006 | Código incorreto, login, confirmação do novo telefone e impossibilidade de reutilização |
| Perfil pessoal | 007 | Nome, e-mail, upload de imagem, duplicidade, propriedade e manutenção da corrida |
| Cadastro de entregador | 008 | CPF e CNH inválidos, duplicidade, bicicleta e mudança para moto |
| Veículo e documentos | 008, 013 | Persistência, normalização da placa e bloqueio durante corrida |
| Pix | 009 | CPF, celular, e-mail, UUID e chave inválida sem sobrescrever a anterior |
| Disponibilidade e GPS | 010, 029 | GPS ausente/antigo, coordenadas inválidas, cadastro inativo, segundo plano e retomada |
| Ofertas | 011, 012, 027 | Recusa, expiração, proprietário, inexistência, concorrência e aviso persistido |
| Corrida | 001–003, 013, 015, 022 | Aceite, retomada, coleta, conclusão, idempotência, código incorreto e bloqueio de outra corrida |
| Rota e destino | 014 | Erro 422 por GPS antigo, recuperação, autorização, coordenadas inválidas e correção persistida |
| Encerramento remoto | 015 | Limpeza da corrida/rota e recuperação do estado após evento externo |
| Suporte | 016–018, 024 | Protocolo idempotente, isolamento, resposta administrativa e renderização na tela |
| Retirada e transferência | 017, 018 | Restrição de cargo, etapa de coleta, confirmação física e mudança do responsável |
| Histórico e ganhos | 019, 026, 030 | Paginação sem duplicatas, filtros, períodos, valores, detalhes, exibição e repetição após falha de rede |
| Avaliações | 001, 019 | Avaliação real após entrega, resumo e estado vazio |
| Repasses | 020, 025 | Não apurado, pendente, pago, valor incorreto, idempotência e apresentação de pagamento efetivo |
| Preferências e avisos | 021, 027 | Persistência das quatro preferências, token do aparelho e destinatário após troca de conta |
| Sessão e logout | 015, 022 | JWT inválido, limpeza dos providers, cache separado por usuário, retomada e estado offline |
| Chat com a loja | 023 | Dois participantes via STOMP real, reconexão, mensagem única por UUID, histórico, paginação, leitura e acesso negado a terceiros |
| Google indisponível | 028 | Rejeição controlada sem substituir a sessão atual |

O cenário `integration_test/motoboy_device_test.dart` complementa a suíte no emulador Android com GPS e aplicativo reais:

```bash
BACKEND_DIR=/caminho/backend-nhac RUN_DEVICE=true DEVICE_ID=emulator-5554 bash tool/run_integration.sh
```

## Isolamento e limites

Cada cenário novo tem usuários, CPF, loja e pedidos próprios. A limpeza desativa os entregadores do cenário para que eles não recebam ofertas de outros testes. O controlador auxiliar exige ADMIN, o perfil `motoboy-integration`, loopback e H2; suas classes são compiladas em diretório temporário e não integram o artefato de produção do backend. Os códigos de e-mail/SMS são consultados apenas por esse controlador local; validação e consumo passam pelos serviços reais.

Entrega de e-mail/SMS, armazenamento externo e cálculo OSRM usam a configuração de integração existente. GPS nos testes host usa um adaptador determinístico. Portanto, esses testes verificam o contrato e o comportamento do aplicativo, sem comprovar entrega externa ou precisão de trajetos. A massa do cenário 019 cria registros históricos para testar consulta/paginação, e o 015 injeta um estado terminal para testar recuperação; eles não comprovam o processo comercial de cancelamento nem 22 entregas realizadas pela interface.

Ainda exigem credenciais e aparelho: Google com conta real, recebimento de SMS/e-mail, FCM/APNs em primeiro/segundo plano e após encerrar o processo, câmera/galeria, ligação telefônica, abertura de navegação externa, GPS contínuo com tela bloqueada e rota real para moto/bicicleta. Os testes host não substituem essa aceitação em dispositivo.

A main atualmente consulta o cache de rota antes da validação de idade do GPS. O cenário 014 muda o destino pelo endpoint real para exigir cálculo novo e então verificar o erro 422. Uma rota já em cache pode continuar disponível com GPS antigo por até a expiração do cache (15 minutos); essa divergência está no backend e não é corrigida por esta suíte.

A main retorna 403 (não 401) para JWT com assinatura inválida. O cenário 022 registra esse contrato e verifica a limpeza ao encerrar a sessão explicitamente; ele não afirma que o aplicativo encerra automaticamente a sessão após esse 403, que também representa falta de permissão legítima.
