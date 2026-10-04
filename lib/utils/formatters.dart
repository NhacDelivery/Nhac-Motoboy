import 'package:intl/intl.dart';

final _real = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 2,
);
String formatarReal(num valor) => _real.format(valor);
