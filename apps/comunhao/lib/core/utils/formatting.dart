import 'package:intl/intl.dart';

String formatDateTimeShort(DateTime value) {
  return DateFormat('dd/MM, HH:mm').format(value.toLocal());
}

String formatDateShort(DateTime value) {
  return DateFormat('dd/MM/yyyy').format(value.toLocal());
}

String formatMoney(num? value, String currency) {
  if (value == null) {
    return '$currency -';
  }

  final formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '$currency ',
    decimalDigits: value % 1 == 0 ? 0 : 2,
  );
  return formatter.format(value);
}
