---
version: alpha
name: "Nhac Motoboy"
description: "Interface de corridas do entregador no universo visual Nhac"
colors:
  primary: "#FF6961"
  secondary: "#FCDABB"
  background: "#FFE7E5"
  text: "#5D201C"
  muted: "#757575"
  border: "#C9BCBC"
  error: "#B3261E"
  success: "#2E7D32"
  surface: "#FFFFFF"
typography:
  body:
    fontFamily: "Roboto, sans-serif"
omitted:
  - section: spacing
    reason: "As medidas existentes usam flutter_screenutil e variam por componente."
  - section: rounded
    reason: "Os raios existentes variam por cartão e controle; não há escala compartilhada."
---

# Nhac Motoboy

## Overview

O produto serve entregadores brasileiros em movimento, principalmente no celular. A tarefa principal é reconhecer uma oferta, aceitar a corrida e acompanhar retirada e entrega sem perder o prazo. O app mantém a identidade coral e rosada do Nhac. O círculo de prazo da oferta é o destaque visual funcional; mapa, status e ações devem permanecer legíveis sob pressão. Evitar aparência de painel financeiro quando o backend mostra somente frete calculado.

`lib/globals/theme_colors.dart` é a fonte dos valores em execução (`AppColors.primaria`, `secundaria`, `fundo`, `texto`, `desabilitado`, `bordaInativa`). Os valores acima espelham essa classe; alterações globais devem atualizar ambos no mesmo commit. O produto usa português brasileiro; valores monetários são apresentados em reais e datas no horário local.

## Colors

Coral identifica ações primárias e ofertas; marrom é texto principal; rosa claro é o fundo. Branco identifica cartões. Estados de erro e sucesso usam texto e ícone além da cor.

## Typography

Roboto está declarado em `pubspec.yaml`. `AppTextStyles` centraliza título, subtítulo e botão. Textos operacionais usam frases curtas e valores legíveis em dispositivos pequenos.

## Layout

Abas inferiores reúnem Início, Corridas, Frete e Perfil, com rótulos sempre visíveis e largura estável. A cápsula branca preserva a navegação do universo Nhac. Áreas de toque preservam SafeArea e espaçamento para o teclado. O cartão de oferta mantém prazo, frete, endereço e decisões no mesmo bloco.

## Elevation & Depth

Cartões brancos usam sombra leve sobre o fundo rosa. O mapa ocupa uma região estável antes da descrição da corrida. Erros de rede aparecem no contexto da ação, com tentativa manual.

## Shapes

Cartões têm cantos arredondados, botões de ação são ovais, ícones operacionais são Material Icons. A forma circular do prazo carrega informação real e usa a janela de 90 segundos do servidor.

## Components

`BotaoLargoNhac` e `AppTextStyles` são os donos compartilhados de botão e tipografia. `EntregaProvider` controla disponibilidade, ofertas e corrida; abas observam a revisão de conclusão para atualizar listas. Ações ocupadas preservam dimensões e impedem toque repetido; estado vazio e falha deixam o próximo passo claro.

## Do's and Don'ts

- Mostrar o horário real da última posição enviada; avisar quando ela envelhecer.
- Identificar valores como frete calculado até existir um contrato de repasse e pagamento.
- Não anunciar uma entrega concluída, uma mensagem enviada ou um status offline sem confirmação do servidor.
- Não introduzir cores ou primitivas globais novas para resolver um único fluxo.

## Operational screens

A confirmação de entrega usa um campo nativo com teclado numérico e quatro dígitos, incluindo zeros iniciais. O código é informado pelo cliente; não é armazenado nem reenviado automaticamente. Erros e bloqueios ficam junto ao campo. A tela de avaliações usa cartões brancos, estrelas com descrição semântica, resumo real do servidor e paginação explícita. Formulários novos usam `InputDecorationTheme`; cartões usam `CardThemeData` em `lib/globals/app_theme.dart`. Botões coral usam texto marrom para contraste; `BotaoLargoNhac` mantém pelo menos 48 px de altura. `AppColors.erro`, `sucesso` e `superficie` são os donos dos novos tons semânticos.
