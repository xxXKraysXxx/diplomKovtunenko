import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Default seed when the user has no custom accent *and* Material You is not
/// active. Picked to match the ncti-new static site (thehexus.ru): deep navy
/// brand primary in light mode, lighter sky-blue in dark mode for AA contrast
/// on near-black surfaces.
const Color appDefaultSeed = Color(0xFF0B3B7C); // ncti --primary (light)
const Color appDefaultSeedLight = Color(0xFF0B3B7C); // ncti --primary (light)
const Color appDefaultSeedDark = Color(0xFF60A5FA); // ncti --primary (dark)

/// Global corner radius applied to the Material button family (Filled /
/// Elevated / Outlined / Text) and FABs so shapes read as "soft" rather than
/// pill or square. Calendar cells, lesson cards and the segmented button
/// keep their own radii tuned to their surface — see [kSegmentedRadius].
const double kButtonRadius = 14.0;

/// Corner radius for the segmented button used in Settings. Kept slightly
/// tighter than [kButtonRadius] so adjacent segments still read as a group.
const double kSegmentedRadius = 12.0;

Color appDefaultSeedFor(Brightness b) =>
    b == Brightness.dark ? appDefaultSeedDark : appDefaultSeedLight;

/// Derive a surface tint from [seed] by locking the hue and pushing lightness
/// to [lightness], while damping saturation by [satFactor] so surfaces don't
/// read as aggressively coloured backgrounds.
Color _seedTint(Color seed, double lightness, {double satFactor = 0.25}) {
  final hsl = HSLColor.fromColor(seed);
  return hsl
      .withLightness(lightness.clamp(0.0, 1.0))
      .withSaturation((hsl.saturation * satFactor).clamp(0.0, 1.0))
      .toColor();
}

/// Build a seed-driven [ColorScheme] whose surface tints all live on the
/// seed's hue. Primary / onPrimary / container tokens come from the stock
/// `fromSeed` derivation; only the surface family is replaced.
ColorScheme buildBrandedScheme({
  required Color seed,
  required Brightness brightness,
}) {
  final base = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  if (brightness == Brightness.dark) {
    // Deep blue-black surfaces, still hinted toward seed.
    return base.copyWith(
      surface: _seedTint(seed, 0.09, satFactor: 0.18),
      surfaceContainerLowest: _seedTint(seed, 0.07, satFactor: 0.18),
      surfaceContainerLow: _seedTint(seed, 0.11, satFactor: 0.18),
      surfaceContainer: _seedTint(seed, 0.13, satFactor: 0.2),
      surfaceContainerHigh: _seedTint(seed, 0.18, satFactor: 0.2),
      surfaceContainerHighest: _seedTint(seed, 0.24, satFactor: 0.22),
      surfaceBright: _seedTint(seed, 0.24, satFactor: 0.22),
      surfaceDim: _seedTint(seed, 0.07, satFactor: 0.18),
    );
  }
  // Near-white, cool, sky-washed surfaces.
  return base.copyWith(
    surface: _seedTint(seed, 0.97, satFactor: 0.28),
    surfaceContainerLowest: _seedTint(seed, 0.99, satFactor: 0.2),
    surfaceContainerLow: _seedTint(seed, 0.95, satFactor: 0.25),
    surfaceContainer: _seedTint(seed, 0.93, satFactor: 0.28),
    surfaceContainerHigh: _seedTint(seed, 0.88, satFactor: 0.3),
    surfaceContainerHighest: _seedTint(seed, 0.82, satFactor: 0.3),
    surfaceBright: _seedTint(seed, 0.95, satFactor: 0.22),
    surfaceDim: _seedTint(seed, 0.88, satFactor: 0.28),
  );
}

ThemeData buildAppTheme({
  required ColorScheme scheme,
  Map<String, Color> paletteOverrides = const {},
}) {
  final palette = AppPalette.fromColorScheme(scheme)
      .applyOverrides(paletteOverrides);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kButtonRadius),
  );
  final segmentedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kSegmentedRadius),
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: scheme.brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [palette],
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Corben',
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: scheme.onSurface,
      ),
    ),
    appBarTheme: scheme.brightness == Brightness.dark
        ? AppBarTheme(
            backgroundColor: scheme.surfaceContainer,
            foregroundColor: scheme.onSurface,
          )
        : null,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: buttonShape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: buttonShape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: buttonShape),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(shape: segmentedShape),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kButtonRadius),
      ),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
    ),
  );
}

/// Light fallback used before the auth-aware seed has resolved.
final appTheme = buildAppTheme(
  scheme: buildBrandedScheme(
    seed: appDefaultSeedLight,
    brightness: Brightness.light,
  ),
);

/// Dark fallback used before the auth-aware seed has resolved.
final appThemeDark = buildAppTheme(
  scheme: buildBrandedScheme(
    seed: appDefaultSeedDark,
    brightness: Brightness.dark,
  ),
);
