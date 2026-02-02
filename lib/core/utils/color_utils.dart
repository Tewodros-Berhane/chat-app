import 'package:flutter/material.dart';

const _avatarPalette = [
  Color(0xFF4F46E5),
  Color(0xFF10B981),
  Color(0xFFF97316),
  Color(0xFF14B8A6),
  Color(0xFFEC4899),
  Color(0xFF6366F1),
];

Color colorFromId(String seed) {
  final index = seed.hashCode.abs() % _avatarPalette.length;
  return _avatarPalette[index];
}
