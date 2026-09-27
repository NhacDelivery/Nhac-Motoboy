# Contrato de interação — Nhac Motoboy

- **Disponibilidade:** entrar online exige localização recente confirmada; sair do app tenta confirmar offline com o servidor. Uma falha de offline durante logout mantém a sessão e permite nova tentativa. Uma corrida ativa impede logout até existir fluxo de suporte/retirada no backend.
- **Oferta:** o servidor define expiração em 90 segundos; sincronização não bloqueia o aceite. Aceite só é concluído após resposta do servidor. O mapa pode carregar em seguida e falhar sem desfazer a corrida.
- **Rota:** falha de busca não produz requisições em toda sincronização. O botão na corrida faz nova tentativa. Posição do entregador tem controle de centralização.
- **Histórico e frete:** conclusão confirmada atualiza ambas as abas. O histórico só contém a região retornada pela API, não endereço completo. `totalGanhos` é soma da taxa de frete bruta; a API ainda não informa valor devido nem valor pago.
- **Chat:** confirmação associa o ID gerado no cliente ao ID persistido no servidor. Reenvio usa o mesmo ID e evita duplicação após perda da resposta. Histórico tem uma busca por vez; reconexão refaz o socket e atualiza a lista.
- **Avisos:** o sino mostra eventos recebidos nesta sessão com o aplicativo aberto. Preferências salvas na conta ainda não ativam push em segundo plano.

`lib/globals/theme_colors.dart` e `DESIGN.md` controlam a identidade visual. `EntregaProvider`, `ChatProvider` e os serviços HTTP são donos dos estados assíncronos compartilhados.
