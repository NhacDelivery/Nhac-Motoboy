class MensagemModel {
  final String id, conversaId, remetenteUsuarioId, conteudo;
  final DateTime enviadaEm;
  MensagemModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String, conversaId = json['conversaId'] as String,
      remetenteUsuarioId = json['remetenteUsuarioId'] as String,
      conteudo = json['conteudo'] as String, enviadaEm = DateTime.parse(json['enviadaEm'] as String);
}