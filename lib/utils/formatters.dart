import 'package:intl/intl.dart';

final _real = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);
String formatarReal(num valor) => _real.format(valor);

String telefoneNacional(String valor) {
  final numeros = valor.replaceAll(RegExp(r'\D'), '');
  return numeros.startsWith('55') &&
          (numeros.length == 12 || numeros.length == 13)
      ? numeros.substring(2)
      : numeros;
}

String telefoneE164(String valor) => '+55${telefoneNacional(valor)}';
