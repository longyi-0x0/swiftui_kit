// The theme the gallery shell runs under.

import 'package:flutter/material.dart';

/// The gallery's skin. Both glass surfaces take their ink from it, including
/// the brightness, which is also pushed down to the native renderer — so the
/// appearance switch moves both lanes at once.
ThemeData galleryTheme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4C8DF6),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF1B1D21)
          : const Color(0xFFF2F3F5),
      visualDensity: VisualDensity.compact,
    );
