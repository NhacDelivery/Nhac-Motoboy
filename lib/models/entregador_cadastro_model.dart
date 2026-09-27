/// Modelo que representa a resposta do cadastro de entregador
class EntregadorCadastroModel {
  final bool ativo;
  final String id;
  final String usuarioId;
  final String? nome;
  final String? email;
  final String? telefone;
  final String? cnh;
  final String? cpf;
  final String? placaVeiculo;
  final String? tipoVeiculo; // MOTO | BICICLETA | CARRO
  final String? corVeiculo;
  final String? modeloVeiculo;
  final String? tipoChavePix;
  final String? chavePix;
  final String statusOperacional; // OFFLINE | ONLINE | EM_ENTREGA
  final double? latitudeAtual;
  final double? longitudeAtual;
  final DateTime? ultimaAtualizacaoLocalizacao;
  final DateTime? dataCadastro;

  EntregadorCadastroModel({
    this.ativo = true,
    required this.id,
    required this.usuarioId,
    this.nome,
    this.email,
    this.telefone,
    this.cnh,
    this.cpf,
    this.placaVeiculo,
    this.tipoVeiculo,
    this.corVeiculo,
    this.modeloVeiculo,
    this.tipoChavePix,
    this.chavePix,
    required this.statusOperacional,
    this.latitudeAtual,
    this.longitudeAtual,
    this.ultimaAtualizacaoLocalizacao,
    this.dataCadastro,
  });

  factory EntregadorCadastroModel.fromJson(Map<String, dynamic> json) {
    return EntregadorCadastroModel(
      ativo: json['ativo'] == true,
      id: json['id']?.toString() ?? '',
      usuarioId: json['usuarioId']?.toString() ?? '',
      // EntregadorResponseDTO (backend) já manda nome/email/telefone do
      // Usuario vinculado — só não estavam sendo lidos aqui, então o app
      // não tinha como preencher a tela de perfil com o nome e telefone
      // que a pessoa acabou de digitar no cadastro.
      nome: json['nome']?.toString(),
      email: json['email']?.toString(),
      telefone: json['telefone']?.toString(),
      cnh: json['cnh']?.toString(),
      cpf: json['cpf']?.toString(),
      placaVeiculo: json['placaVeiculo']?.toString(),
      tipoVeiculo: json['tipoVeiculo']?.toString(),
      corVeiculo: json['corVeiculo']?.toString(),
      modeloVeiculo: json['modeloVeiculo']?.toString(),
      tipoChavePix: json['tipoChavePix']?.toString(),
      chavePix: json['chavePix']?.toString(),
      statusOperacional: json['statusOperacional']?.toString() ?? 'OFFLINE',
      latitudeAtual: (json['latitudeAtual'] as num?)?.toDouble(),
      longitudeAtual: (json['longitudeAtual'] as num?)?.toDouble(),
      ultimaAtualizacaoLocalizacao: json['ultimaAtualizacaoLocalizacao'] != null
          ? DateTime.tryParse(json['ultimaAtualizacaoLocalizacao'].toString())
          : null,
      dataCadastro: json['dataCadastro'] != null
          ? DateTime.parse(json['dataCadastro'].toString())
          : null,
    );
  }
}

/// Modelo que representa um erro de negócio retornado pela API.
/// Campos alinhados com ErroPadraoDTO do backend (requestId, timestamp,
/// status, error, title, message, details, path, suggestions) — 'mensagem'
/// e 'caminho' nunca existiram na resposta real (o backend manda 'message'
/// e 'path'), então toda mensagem de erro de negócio (ex: "Este e-mail já
/// está em uso", "Placa já cadastrada") virava sempre o fallback genérico
/// "Erro desconhecido" em vez do motivo real.
class ErroPadraoDTO {
  final int status;
  final String mensagem;
  final String? caminho;
  final DateTime? timestamp;

  ErroPadraoDTO({
    required this.status,
    required this.mensagem,
    this.caminho,
    this.timestamp,
  });

  factory ErroPadraoDTO.fromJson(Map<String, dynamic> json) {
    return ErroPadraoDTO(
      status: json['status'] as int? ?? 0,
      mensagem: json['message']?.toString() ?? 'Erro desconhecido',
      caminho: json['path']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : null,
    );
  }
}
