import 'package:flutter/material.dart';

/// Extension on [ColorScheme] providing custom semantic tokens not in MD3.
/// Access via `Theme.of(context).colorScheme.success` etc.
///
/// Values branch on [ColorScheme.brightness] since `ColorScheme.fromSeed()`
/// has no mechanism for toning custom extension colors — dark values are
/// picked from the same hue lines as light (green/gold), tuned individually
/// for contrast against dark surfaces.
extension AppColors on ColorScheme {
  bool get _isDark => brightness == Brightness.dark;

  // Success
  Color get success =>
      _isDark ? const Color(0xFF7DD996) : const Color(0xFF276234);
  Color get successContainer =>
      _isDark ? const Color(0xFF0F3D1E) : const Color(0xFFC8F0D0);
  // Dark on-color reuses light theme's successContainer hex directly — it
  // already meets 4.5:1 against the darker container fill (see contrast_test.dart).
  Color get onSuccessContainer =>
      _isDark ? const Color(0xFFC8F0D0) : const Color(0xFF002111);

  // Warning
  Color get warning =>
      _isDark ? const Color(0xFFE8C24C) : const Color(0xFF7A5800);
  Color get warningContainer =>
      _isDark ? const Color(0xFF4A3800) : const Color(0xFFFFDEA3);
  // Dark on-color reuses light theme's warningContainer hex directly — it
  // already meets 4.5:1 against the darker container fill (see contrast_test.dart).
  Color get onWarningContainer =>
      _isDark ? const Color(0xFFFFDEA3) : const Color(0xFF281900);
}
