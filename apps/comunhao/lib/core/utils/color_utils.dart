import 'package:flutter/material.dart';

Color parseHexColor(
  String? value, {
  Color fallback = const Color(0xFF1F6F54),
}) {
  if (value == null || value.trim().isEmpty) {
    return fallback;
  }

  final hex = value.trim().replaceAll('#', '');
  if (hex.length != 6 && hex.length != 8) {
    return fallback;
  }

  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  return Color(int.parse(normalized, radix: 16));
}
