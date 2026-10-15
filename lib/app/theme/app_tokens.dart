import 'package:flutter/material.dart';

abstract final class AppTokens {
  // A warm, nearly neutral page; white content cards sit on it with a
  // hairline and a soft shadow. Pink is kept for selection and emphasis, so
  // it is never washed across whole surfaces.
  static const pageLight = Color(0xFFF7F5F6);
  static const pageDark = Color(0xFF131215);
  static const contentLight = Colors.white;
  static const contentDark = Color(0xFF1D1C20);
  static const controlLight = Color(0xFFF1ECEF);
  static const controlDark = Color(0xFF29272D);
  static const textLight = Color(0xFF1F1D24);
  static const textDark = Color(0xFFF2F0F4);
  static const secondaryLight = Color(0xFF6A6470);
  static const secondaryDark = Color(0xFFB8B1BC);
  static const dividerLight = Color(0xFFECE6EA);
  static const dividerDark = Color(0xFF322F36);
  static const selectedLight = Color(0xFFFBE3EB);
  static const selectedDark = Color(0xFF4A2938);
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

  /// Page side margin: 16 on phones, the same as the feeds' grids, and 24
  /// once there is room.
  static double gutter(double width) => width >= 600 ? 24 : 16;

  /// The widest a root page's content grows; past it, the page keeps its
  /// start and leaves the rest of the window empty rather than centring.
  static const pageWidth = 1360.0;

  /// Space between sections of a page, and between items in a section.
  static const sectionGap = 32.0;
  static const itemGap = 12.0;

  /// Artwork tiles keep one stable portrait box: the model carries no image
  /// dimensions, and a box that changed with each decode would move the grid.
  static const artworkRatio = 4 / 5;
  static const artworkRadius = 12.0;

  /// The widest a line of reading text runs: about 40 Chinese characters
  /// at the reading size. Wider windows centre the column.
  static const readingWidth = 720.0;

  /// Selection, expansion and fades.
  static const controlMotion = Duration(milliseconds: 240);

  /// A press sinking in and coming back.
  static const pressMotion = Duration(milliseconds: 120);

  /// Larger moves: a channel or a section arriving.
  static const emphasisMotion = Duration(milliseconds: 360);

  static const cardRadius = 16.0;
  static const inputRadius = 12.0;
  static const panelRadius = 28.0;

  /// A content card's lift: a hairline does the separating, the shadow only
  /// suggests the card is above the page. Dark pages rely on the hairline.
  static List<BoxShadow> cardShadow(Brightness brightness) =>
      brightness == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x14501C30),
            blurRadius: 24,
            spreadRadius: -12,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ];
}
