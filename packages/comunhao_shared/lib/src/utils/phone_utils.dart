String normalizePhone(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Introduz um numero de telefone.');
  }

  final hasPlus = trimmed.startsWith('+');
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');

  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }

  if (digits.startsWith('0') && digits.length >= 10) {
    digits = digits.substring(1);
  }

  if (hasPlus) {
    return '+$digits';
  }

  if (digits.startsWith('258')) {
    return '+$digits';
  }

  if (digits.length == 9) {
    return '+258$digits';
  }

  if (digits.length < 9) {
    throw const FormatException('Numero de telefone invalido.');
  }

  return '+$digits';
}

String maskPhone(String input) {
  final normalized = normalizePhone(input);
  if (normalized.length <= 6) {
    return normalized;
  }

  return '${normalized.substring(0, normalized.length - 3)}***';
}
