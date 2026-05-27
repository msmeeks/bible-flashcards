import 'package:flutter/material.dart';

/// Extension on [ColorScheme] providing custom semantic tokens not in MD3.
/// Access via `Theme.of(context).colorScheme.success` etc.
extension AppColors on ColorScheme {
  // Success
  Color get success => const Color(0xFF276234);
  Color get successContainer => const Color(0xFFC8F0D0);
  Color get onSuccessContainer => const Color(0xFF002111);

  // Warning
  Color get warning => const Color(0xFF7A5800);
  Color get warningContainer => const Color(0xFFFFDEA3);
  Color get onWarningContainer => const Color(0xFF281900);
}
