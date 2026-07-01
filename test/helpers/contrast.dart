import 'dart:math';

import 'package:flutter/material.dart';

/// WCAG 2.x relative luminance / contrast ratio helpers.
/// https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
double _linearize(double channel) {
  return channel <= 0.03928
      ? channel / 12.92
      : pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color color) {
  final r = _linearize(color.r);
  final g = _linearize(color.g);
  final b = _linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a) + 0.05;
  final lb = relativeLuminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}
