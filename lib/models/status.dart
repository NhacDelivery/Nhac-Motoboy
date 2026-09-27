enum StatusPedido {
  pendente('PENDENTE', 'Aguardando pagamento'), pago('PAGO', 'Pago'),
  preparando('PREPARANDO', 'Retirar na loja'), saiuEntrega('SAIU_ENTREGA', 'A caminho do cliente'),
  entregue('ENTREGUE', 'Entregue'), cancelado('CANCELADO', 'Cancelado'),
  desconhecido('DESCONHECIDO', 'Status indisponível');
  final String api;
  final String label;
  const StatusPedido(this.api, this.label);
  static StatusPedido parse(Object? value) => values.firstWhere(
    (s) => s.api == value, orElse: () => desconhecido);
  bool get ativo => this == preparando || this == saiuEntrega;
}
enum StatusOperacional {
  offline('OFFLINE', 'Offline'), online('ONLINE', 'Online'),
  emEntrega('EM_ENTREGA', 'Em entrega'), desconhecido('DESCONHECIDO', 'Indisponível');
  final String api;
  final String label;
  const StatusOperacional(this.api, this.label);
  static StatusOperacional parse(Object? value) => values.firstWhere(
    (s) => s.api == value?.toString().trim().toUpperCase(),
    orElse: () => desconhecido);
}
