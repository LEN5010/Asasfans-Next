import 'package:flutter/material.dart';

abstract final class AppTokens {
  // Neutral surfaces carry a faint Diana-pink cast; content cards stay white.
  static const pageLight = Color(0xFFFBF6F8);
  static const pageDark = Color(0xFF1A1618);
  static const contentLight = Colors.white;
  static const contentDark = Color(0xFF252124);
  static const controlLight = Color(0xFFF5ECF0);
  static const controlDark = Color(0xFF30292D);
  static const textLight = Color(0xFF25252B);
  static const textDark = Color(0xFFF1F0F3);
  static const secondaryLight = Color(0xFF6E6770);
  static const secondaryDark = Color(0xFFBDB5BB);
  static const dividerLight = Color(0xFFEFE4E9);
  static const dividerDark = Color(0xFF3E363A);
  static const selectedLight = Color(0xFFF9DCE6);
  static const selectedDark = Color(0xFF4A2A37);
  static const cardRadius = 14.0;
  static const inputRadius = 12.0;
  static const panelRadius = 24.0;
}
