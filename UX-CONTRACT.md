# Contrato de interação — Nhac Motoboy

- **Disponibilidade:** entrar online exige localização recente confirmada; sair do app tenta confirmar offline com o servidor. Uma falha de offline durante logout mantém a sessão e permite nova tentativa. Uma corrida ativa impede logout até existir fluxo de suporte/retirada no backend.
- **Oferta:** o servidor define expiração em 90 segundos; sincronização não bloqueia o aceite. Aceite só é concluído após resposta do servidor. O mapa pode carregar em seguida e falhar sem desfazer a corrida.
- **Rota:** falha de busca não produz requisições em toda sincronização. O botão na corrida faz nova tentativa. Posição do entregador tem controle de centralização.
- **Histórico e frete:** conclusão confirmada atualiza ambas as abas. O histórico só contém a região retornada pela API, não endereço completo. `totalGanhos` é soma da taxa de frete bruta; a API ainda não informa valor devido nem valor pago.
- **Chat:** confirmação associa o ID gerado no cliente ao ID persistido no servidor. Reenvio usa o mesmo ID e evita duplicação após perda da resposta. Histórico tem uma busca por vez; reconexão refaz o socket e atualiza a lista.
- **Avisos:** o sino mostra eventos recebidos nesta sessão com o aplicativo aberto. Preferências salvas na conta ainda não ativam push em segundo plano.

`lib/globals/theme_colors.dart` e `DESIGN.md` controlam a identidade visual. `EntregaProvider`, `ChatProvider` e os serviços HTTP são donos dos estados assíncronos compartilhados.

- **Código de entrega:** `EntregaController.concluirEntrega` e `CodigoEntregaService` da main do backend são as fontes de autorização. Enviar `{codigo}` com quatro números depois da retirada. Código incorreto preserva a corrida e mostra tentativas restantes; HTTP 429 mostra `tentativaLiberadaEm` e bloqueia o botão até o horário. Timeout não repete a conclusão: o provider reconsulta a corrida para reconciliar o resultado.
- **Avaliações:** `EntregadorController.listarAvaliacoes` retorna `resumo` e `avaliacoes` paginadas. Mostrar média e total da API, preservar avaliações carregadas em falhas e oferecer recuperação e Carregar mais. Nenhuma avaliação é criada pelo entregador.
- **Atualização:** eventos WebSocket atualizam a corrida; polling de recuperação usa 30 s com socket conectado, 10 s sem socket e 60 s offline. GPS mantém heartbeat de 30 s para o limite de frescor do backend; precisão média aguardando ofertas e alta durante corrida. Contador pertence ao cartão de oferta, sem reconstruir toda a aplicação.

Fontes verificadas: backend-nhac/main no commit `48f553f345ab4925fe74e164f5947705e9c0bb8c`; `domain/entrega/EntregaController.java`, `domain/entrega/CodigoEntregaService.java`, `domain/entregador/EntregadorController.java`, `domain/avaliacao_entregador/dto/AvaliacoesEntregadorPageDTO.java` e `domain/entregador/EntregadorService.java`. A identidade visual foi comparada com `Nhac/main/lib/globals/themes.dart` (Roboto, coral #FF6961 e fundo #FFE7E5).
