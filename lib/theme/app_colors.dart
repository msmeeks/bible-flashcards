import 'package:flutter/material.dart';

/// Extension on [ColorScheme] providing custom semantic tokens not in MD3.
/// Access via `Theme.of(context).colorScheme.success` etc.
///
/// Values branch on [ColorScheme.brightness] since `ColorScheme.fromSeed()`
/// has no mechanism for toning custom extension colors — dark values are
/// picked from the same hue lines as light (green/gold), tuned individually
/// for contrast against dark surfaces.
///
/// `errorContainer`/`onErrorContainer` are real [ColorScheme] fields rather
/// than custom tokens here — their dark overrides live in app_theme.dart's
/// `dark()` instead.
extension AppColors on ColorScheme {
  bool get _isDark => brightness == Brightness.dark;

  // Success
  Color get success =>
      _isDark ? const Color(0xFF7DD996) : const Color(0xFF276234);
  Color get successContainer =>
      _isDark ? const Color(0xFF1D7439) : const Color(0xFFC8F0D0);
  // Dark on-color reuses light theme's successContainer hex directly — it
  // still meets 4.5:1 against the lightened dark container fill (see contrast_test.dart).
  Color get onSuccessContainer =>
      _isDark ? const Color(0xFFC8F0D0) : const Color(0xFF002111);

  // Warning — lightened by a smaller amount than success/error (see issue #138).
  Color get warning =>
      _isDark ? const Color(0xFFE8C24C) : const Color(0xFF7A5800);
  Color get warningContainer =>
      _isDark ? const Color(0xFF816100) : const Color(0xFFFFDEA3);
  // Dark on-color can't reuse the light theme's warningContainer hex here —
  // it no longer clears 4.5:1 against the lightened dark container fill, so
  // this is a dedicated dark-only value (see contrast_test.dart).
  Color get onWarningContainer =>
      _isDark ? const Color(0xFFFFF2CC) : const Color(0xFF281900);
}
