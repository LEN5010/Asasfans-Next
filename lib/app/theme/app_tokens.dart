import 'package:flutter/material.dart';

abstract final class AppTokens {
  // Neutral surfaces carry a faint Diana-pink cast; content cards stay white.
  static const pageLight = Color(0xFFFBF6F8);
  static const pageDark = Color(0xFF19191C);
  static const contentLight = Colors.white;
  static const contentDark = Color(0xFF232326);
  static const controlLight = Color(0xFFF5ECF0);
  static const controlDark = Color(0xFF2D2D31);
  static const textLight = Color(0xFF25252B);
  static const textDark = Color(0xFFF1F0F3);
  static const secondaryLight = Color(0xFF6E6770);
  static const secondaryDark = Color(0xFFBDB5BB);
  static const dividerLight = Color(0xFFEFE4E9);
  static const dividerDark = Color(0xFF38383D);
  static const selectedLight = Color(0xFFF9DCE6);
  static const selectedDark = Color(0xFF4A2A37);
  // Compact controls in LoveIwara's proportions: 40 on touch widths, 34 on
  // wide desktop windows; wide rows keep their larger hit area by width.
  static const controlHeight = 40.0;
  static double controlTarget(BuildContext context) =>
      switch (Theme.of(context).platform) {
        TargetPlatform.android || TargetPlatform.iOS => 40,
        _ => MediaQuery.sizeOf(context).width < 600 ? 40 : 34,
      };

  /// Whether this platform is operated by fingers. Visual size and hit area
  /// are separate there: controls may look 40 dp, but are hit at 48 dp.
  static bool touch(BuildContext context) =>
      switch (Theme.of(context).platform) {
        TargetPlatform.android || TargetPlatform.iOS => true,
        _ => false,
      };

  /// The minimum hit area for a control (Android guidance: 48 × 48 dp).
  static double touchTarget(BuildContext context) =>
      touch(context) ? 48 : controlTarget(context);
  static const controlMotion = Duration(milliseconds: 220);
  static const pressMotion = Duration(milliseconds: 140);
  static const cardRadius = 14.0;
  static const inputRadius = 12.0;
  static const panelRadius = 24.0;
}
