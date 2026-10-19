import 'package:flutter/material.dart';

/// Design tokens from "FixMyCampus Screens v2" (docs/design/screens-v2.html).
///
/// Names follow the design's own palette variables where it has them
/// (P, PP, PK, OR, K, W, S).
abstract final class AppColors {
  // Brand
  static const periwinkle = Color(0xFF9DB5FA); // P
  static const periwinkleLight = Color(0xFFD9E2FD); // PP
  static const periwinkleMid = Color(0xFFB3C6FC);
  static const pink = Color(0xFFE9A8F2); // PK
  static const orange = Color(0xFFF2913A); // OR

  // Neutrals
  static const ink = Color(0xFF111111); // K — primary text, primary buttons
  static const white = Color(0xFFFFFFFF); // W
  static const surface = Color(0xFFF3F4F8); // S — inputs, chips, tiles
  static const surfaceRow = Color(0xFFF7F8FB); // list rows
  static const border = Color(0xFFE4E6EE);
  static const divider = Color(0xFFEEF0F5);
  static const canvas = Color(0xFFE8EAF1); // behind sheets/scrims

  // Text
  static const textSecondary = Color(0xFF6B6F7C);
  static const textTertiary = Color(0xFF8A8E9B);
  static const textStrong = Color(0xFF3B3F4C);
  static const textOnPeriwinkle = Color(0xFF22283E);

  // Status pills
  static const statusReported = Color(0xFFFDE4CD);
  static const statusInProgress = periwinkleLight;
  static const statusResolved = Color(0xFFD7F0E1);
  static const statusReopened = Color(0xFFF6D8FA);

  static const error = Color(0xFFC4314B);
}

/// Corner radii used by the design (fully rounded pills are height / 2).
abstract final class AppRadii {
  static const card = 28.0; // list rows, info banners, tiles
  static const hero = 32.0; // large coloured cards
  static const sheet = 40.0;
  static const pill = 999.0;
}

/// Fixed control heights.
abstract final class AppSizes {
  static const field = 54.0; // text fields and primary buttons
  static const chip = 44.0;
  static const iconButton = 48.0;
  static const avatar = 48.0;
  static const bottomNav = 76.0;
  static const fab = 52.0;
  static const gutter = 20.0; // screen side padding
}
