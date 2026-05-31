import 'package:flutter/material.dart';

/// Stable string ids for every semantic token. Used as the SharedPreferences
/// key suffix for debug overrides (`palette.override.<id>`) so the override
/// lookup stays independent of Dart field order.
class PaletteTokens {
  /// Debug-only override key: forces [ColorScheme.fromSeed] to use this colour
  /// as its seed, overriding both the user's accent and the default brand seed.
  /// Not part of [all]; consumed directly in `main.dart` before the scheme is
  /// built, so it bypasses the usual [AppPalette.applyOverrides] path.
  static const seed = 'seed';

  static const noteBackground = 'noteBackground';
  static const noteForeground = 'noteForeground';
  static const noteBorder = 'noteBorder';
  static const notificationIndicator = 'notificationIndicator';
  static const scheduleHasLessons = 'scheduleHasLessons';
  static const scheduleEvenWeek = 'scheduleEvenWeek';
  static const scheduleOddWeek = 'scheduleOddWeek';
  static const scheduleNoLessonsInMonth = 'scheduleNoLessonsInMonth';
  static const scheduleNoLessonsOutMonth = 'scheduleNoLessonsOutMonth';
  static const scheduleSelected = 'scheduleSelected';
  static const scheduleSelectedText = 'scheduleSelectedText';
  static const scheduleTodayRing = 'scheduleTodayRing';
  static const scheduleInMonthText = 'scheduleInMonthText';
  static const scheduleOutMonthText = 'scheduleOutMonthText';
  static const scheduleOverride = 'scheduleOverride';
  static const newsAccent = 'newsAccent';
  static const surfaceElevated = 'surfaceElevated';
  static const lessonCardFill = 'lessonCardFill';
  static const lessonCardBorder = 'lessonCardBorder';
  static const lessonCardTitle = 'lessonCardTitle';
  static const lessonCardSubtitle = 'lessonCardSubtitle';
  static const emptySlotFill = 'emptySlotFill';
  static const emptySlotBorder = 'emptySlotBorder';
  static const emptySlotText = 'emptySlotText';
  static const subtleDivider = 'subtleDivider';
  static const mutedLabel = 'mutedLabel';
  static const dayHeadingText = 'dayHeadingText';
  static const weekHeaderText = 'weekHeaderText';
  static const lessonBadgeFill = 'lessonBadgeFill';
  static const lessonBadgeText = 'lessonBadgeText';

  /// All tokens in a stable order (used for the debug list view).
  static const all = <String>[
    noteBackground,
    noteForeground,
    noteBorder,
    notificationIndicator,
    scheduleHasLessons,
    scheduleEvenWeek,
    scheduleOddWeek,
    scheduleNoLessonsInMonth,
    scheduleNoLessonsOutMonth,
    scheduleSelected,
    scheduleSelectedText,
    scheduleTodayRing,
    scheduleInMonthText,
    scheduleOutMonthText,
    scheduleOverride,
    newsAccent,
    surfaceElevated,
    lessonCardFill,
    lessonCardBorder,
    lessonCardTitle,
    lessonCardSubtitle,
    emptySlotFill,
    emptySlotBorder,
    emptySlotText,
    subtleDivider,
    mutedLabel,
    dayHeadingText,
    weekHeaderText,
    lessonBadgeFill,
    lessonBadgeText,
  ];
}

/// Semantic color tokens derived from the active [ColorScheme].
///
/// Centralises the palette so screens don't sprinkle `Color(0xFF…)` literals
/// across the tree. Tokens are grouped by purpose (notes, schedule, lesson
/// cards, …) — pick the one that names the surface, not its hex value.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  // Notes (sticky-note style cards on the schedule day view)
  final Color noteBackground;
  final Color noteForeground;
  final Color noteBorder;

  // Notification / pinned-note outlines on the calendar grid
  final Color notificationIndicator;

  // Calendar day cells
  final Color scheduleHasLessons;
  final Color scheduleEvenWeek;
  final Color scheduleOddWeek;
  final Color scheduleNoLessonsInMonth;
  final Color scheduleNoLessonsOutMonth;
  final Color scheduleSelected;
  final Color scheduleSelectedText;
  final Color scheduleTodayRing;
  final Color scheduleInMonthText;
  final Color scheduleOutMonthText;

  // Lesson with operator-modified row — kept as fixed amber so the
  // "warning" semantic stays universal regardless of seed colour.
  final Color scheduleOverride;

  // News card accent
  final Color newsAccent;

  // Elevated surface (cards/chips on top of background)
  final Color surfaceElevated;

  // Lesson cards (per-lesson cells in the day view)
  final Color lessonCardFill;
  final Color lessonCardBorder;
  final Color lessonCardTitle;
  final Color lessonCardSubtitle;

  // Empty / placeholder slots
  final Color emptySlotFill;
  final Color emptySlotBorder;
  final Color emptySlotText;

  // Misc
  final Color subtleDivider;
  final Color mutedLabel;
  final Color dayHeadingText;
  final Color weekHeaderText;

  // Subject-number badge on lesson cards
  final Color lessonBadgeFill;
  final Color lessonBadgeText;

  const AppPalette({
    required this.noteBackground,
    required this.noteForeground,
    required this.noteBorder,
    required this.notificationIndicator,
    required this.scheduleHasLessons,
    required this.scheduleEvenWeek,
    required this.scheduleOddWeek,
    required this.scheduleNoLessonsInMonth,
    required this.scheduleNoLessonsOutMonth,
    required this.scheduleSelected,
    required this.scheduleSelectedText,
    required this.scheduleTodayRing,
    required this.scheduleInMonthText,
    required this.scheduleOutMonthText,
    required this.scheduleOverride,
    required this.newsAccent,
    required this.surfaceElevated,
    required this.lessonCardFill,
    required this.lessonCardBorder,
    required this.lessonCardTitle,
    required this.lessonCardSubtitle,
    required this.emptySlotFill,
    required this.emptySlotBorder,
    required this.emptySlotText,
    required this.subtleDivider,
    required this.mutedLabel,
    required this.dayHeadingText,
    required this.weekHeaderText,
    required this.lessonBadgeFill,
    required this.lessonBadgeText,
  });

  /// Universal warning amber — kept fixed across light/dark and across
  /// any seed colour, matching the semantic Material amber 400.
  static const Color overrideAmber = Color(0xFFFFA726);

  /// Build a palette from a Material 3 [ColorScheme].
  factory AppPalette.fromColorScheme(ColorScheme s) {
    final isDark = s.brightness == Brightness.dark;
    final primaryHsl = HSLColor.fromColor(s.primaryContainer);
    // Notes: same hue family as lessons (no hue shift) but a small lightness
    // delta keeps them distinguishable when rendered next to day cells.
    final noteBgLightness =
        (primaryHsl.lightness + (isDark ? -0.05 : 0.05)).clamp(0.0, 1.0);
    final noteBg = primaryHsl.withLightness(noteBgLightness).toColor();
    final noteFg = s.onPrimaryContainer;
    // V2-F formula (chosen after reviewing color-variants-v2-family.html).
    // Even and odd straddle `primaryContainer`'s hue symmetrically, with odd
    // also dropping in lightness so the two weeks read as distinct tonal
    // siblings — not a hue-only difference that washes out at low saturation.
    final oddHue = (primaryHsl.hue + (isDark ? -14.0 : 12.0)) % 360.0;
    final oddLightness = (primaryHsl.lightness - (isDark ? 0.06 : 0.05))
        .clamp(0.0, 1.0);
    final oddWeek = primaryHsl
        .withHue(oddHue < 0 ? oddHue + 360.0 : oddHue)
        .withLightness(oddLightness)
        .toColor();
    final evenHue = (primaryHsl.hue + (isDark ? 7.0 : -6.0)) % 360.0;
    final evenWeek = primaryHsl
        .withHue(evenHue < 0 ? evenHue + 360.0 : evenHue)
        .toColor();
    // Empty-day tint: V2-F bumps the lightness delta to −5% / +6% so the
    // schedule area reads as a stronger "island" off the scaffold without
    // bleeding into the has-lessons family (which derives from primaryContainer,
    // not surface). Out-of-month stays smaller to preserve in/out hierarchy.
    final surfaceHsl = HSLColor.fromColor(s.surface);
    final noLessonsInLightness =
        (surfaceHsl.lightness + (isDark ? 0.06 : -0.05)).clamp(0.0, 1.0);
    final noLessonsInTint =
        surfaceHsl.withLightness(noLessonsInLightness).toColor();
    final noLessonsOutLightness =
        (surfaceHsl.lightness + (isDark ? 0.03 : -0.025)).clamp(0.0, 1.0);
    final noLessonsOutTint =
        surfaceHsl.withLightness(noLessonsOutLightness).toColor();
    return AppPalette(
      noteBackground: noteBg,
      noteForeground: noteFg,
      noteBorder: Color.alphaBlend(
        noteFg.withOpacity(isDark ? 0.45 : 0.35),
        noteBg,
      ),
      notificationIndicator: s.error,
      scheduleHasLessons: s.primaryContainer,
      scheduleEvenWeek: evenWeek,
      scheduleOddWeek: oddWeek,
      scheduleNoLessonsInMonth: noLessonsInTint,
      scheduleNoLessonsOutMonth: noLessonsOutTint,
      scheduleSelected: s.primary,
      scheduleSelectedText: s.onPrimary,
      scheduleTodayRing: s.onSurface,
      scheduleInMonthText: s.onSurface,
      scheduleOutMonthText: s.onSurfaceVariant,
      scheduleOverride: overrideAmber,
      newsAccent: s.secondary,
      surfaceElevated: s.surfaceContainerHigh,
      lessonCardFill: s.surfaceContainer,
      lessonCardBorder: s.outlineVariant,
      lessonCardTitle: s.onSurface,
      lessonCardSubtitle: s.onSurfaceVariant,
      emptySlotFill: s.surfaceContainerLow,
      emptySlotBorder: s.outlineVariant,
      emptySlotText: s.onSurfaceVariant.withOpacity(0.65),
      subtleDivider: s.outlineVariant,
      mutedLabel: s.onSurfaceVariant,
      dayHeadingText: s.onSurface,
      weekHeaderText: s.onSurfaceVariant,
      lessonBadgeFill: s.primaryContainer,
      lessonBadgeText: s.onPrimaryContainer,
    );
  }

  /// Return a copy with any tokens in [overrides] replaced. Token ids must
  /// match [PaletteTokens]. Unknown keys are ignored so the caller can safely
  /// persist stale names.
  AppPalette applyOverrides(Map<String, Color> overrides) {
    if (overrides.isEmpty) return this;
    Color pick(String key, Color fallback) => overrides[key] ?? fallback;
    return AppPalette(
      noteBackground: pick(PaletteTokens.noteBackground, noteBackground),
      noteForeground: pick(PaletteTokens.noteForeground, noteForeground),
      noteBorder: pick(PaletteTokens.noteBorder, noteBorder),
      notificationIndicator:
          pick(PaletteTokens.notificationIndicator, notificationIndicator),
      scheduleHasLessons:
          pick(PaletteTokens.scheduleHasLessons, scheduleHasLessons),
      scheduleEvenWeek:
          pick(PaletteTokens.scheduleEvenWeek, scheduleEvenWeek),
      scheduleOddWeek: pick(PaletteTokens.scheduleOddWeek, scheduleOddWeek),
      scheduleNoLessonsInMonth: pick(
          PaletteTokens.scheduleNoLessonsInMonth, scheduleNoLessonsInMonth),
      scheduleNoLessonsOutMonth: pick(
          PaletteTokens.scheduleNoLessonsOutMonth, scheduleNoLessonsOutMonth),
      scheduleSelected:
          pick(PaletteTokens.scheduleSelected, scheduleSelected),
      scheduleSelectedText:
          pick(PaletteTokens.scheduleSelectedText, scheduleSelectedText),
      scheduleTodayRing:
          pick(PaletteTokens.scheduleTodayRing, scheduleTodayRing),
      scheduleInMonthText:
          pick(PaletteTokens.scheduleInMonthText, scheduleInMonthText),
      scheduleOutMonthText:
          pick(PaletteTokens.scheduleOutMonthText, scheduleOutMonthText),
      scheduleOverride:
          pick(PaletteTokens.scheduleOverride, scheduleOverride),
      newsAccent: pick(PaletteTokens.newsAccent, newsAccent),
      surfaceElevated: pick(PaletteTokens.surfaceElevated, surfaceElevated),
      lessonCardFill: pick(PaletteTokens.lessonCardFill, lessonCardFill),
      lessonCardBorder:
          pick(PaletteTokens.lessonCardBorder, lessonCardBorder),
      lessonCardTitle: pick(PaletteTokens.lessonCardTitle, lessonCardTitle),
      lessonCardSubtitle:
          pick(PaletteTokens.lessonCardSubtitle, lessonCardSubtitle),
      emptySlotFill: pick(PaletteTokens.emptySlotFill, emptySlotFill),
      emptySlotBorder: pick(PaletteTokens.emptySlotBorder, emptySlotBorder),
      emptySlotText: pick(PaletteTokens.emptySlotText, emptySlotText),
      subtleDivider: pick(PaletteTokens.subtleDivider, subtleDivider),
      mutedLabel: pick(PaletteTokens.mutedLabel, mutedLabel),
      dayHeadingText: pick(PaletteTokens.dayHeadingText, dayHeadingText),
      weekHeaderText: pick(PaletteTokens.weekHeaderText, weekHeaderText),
      lessonBadgeFill: pick(PaletteTokens.lessonBadgeFill, lessonBadgeFill),
      lessonBadgeText: pick(PaletteTokens.lessonBadgeText, lessonBadgeText),
    );
  }

  /// Look up a token by id — used by the debug UI to render current swatches.
  Color byToken(String token) {
    switch (token) {
      case PaletteTokens.noteBackground:
        return noteBackground;
      case PaletteTokens.noteForeground:
        return noteForeground;
      case PaletteTokens.noteBorder:
        return noteBorder;
      case PaletteTokens.notificationIndicator:
        return notificationIndicator;
      case PaletteTokens.scheduleHasLessons:
        return scheduleHasLessons;
      case PaletteTokens.scheduleEvenWeek:
        return scheduleEvenWeek;
      case PaletteTokens.scheduleOddWeek:
        return scheduleOddWeek;
      case PaletteTokens.scheduleNoLessonsInMonth:
        return scheduleNoLessonsInMonth;
      case PaletteTokens.scheduleNoLessonsOutMonth:
        return scheduleNoLessonsOutMonth;
      case PaletteTokens.scheduleSelected:
        return scheduleSelected;
      case PaletteTokens.scheduleSelectedText:
        return scheduleSelectedText;
      case PaletteTokens.scheduleTodayRing:
        return scheduleTodayRing;
      case PaletteTokens.scheduleInMonthText:
        return scheduleInMonthText;
      case PaletteTokens.scheduleOutMonthText:
        return scheduleOutMonthText;
      case PaletteTokens.scheduleOverride:
        return scheduleOverride;
      case PaletteTokens.newsAccent:
        return newsAccent;
      case PaletteTokens.surfaceElevated:
        return surfaceElevated;
      case PaletteTokens.lessonCardFill:
        return lessonCardFill;
      case PaletteTokens.lessonCardBorder:
        return lessonCardBorder;
      case PaletteTokens.lessonCardTitle:
        return lessonCardTitle;
      case PaletteTokens.lessonCardSubtitle:
        return lessonCardSubtitle;
      case PaletteTokens.emptySlotFill:
        return emptySlotFill;
      case PaletteTokens.emptySlotBorder:
        return emptySlotBorder;
      case PaletteTokens.emptySlotText:
        return emptySlotText;
      case PaletteTokens.subtleDivider:
        return subtleDivider;
      case PaletteTokens.mutedLabel:
        return mutedLabel;
      case PaletteTokens.dayHeadingText:
        return dayHeadingText;
      case PaletteTokens.weekHeaderText:
        return weekHeaderText;
      case PaletteTokens.lessonBadgeFill:
        return lessonBadgeFill;
      case PaletteTokens.lessonBadgeText:
        return lessonBadgeText;
    }
    return Colors.transparent;
  }

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  @override
  AppPalette copyWith({
    Color? noteBackground,
    Color? noteForeground,
    Color? noteBorder,
    Color? notificationIndicator,
    Color? scheduleHasLessons,
    Color? scheduleEvenWeek,
    Color? scheduleOddWeek,
    Color? scheduleNoLessonsInMonth,
    Color? scheduleNoLessonsOutMonth,
    Color? scheduleSelected,
    Color? scheduleSelectedText,
    Color? scheduleTodayRing,
    Color? scheduleInMonthText,
    Color? scheduleOutMonthText,
    Color? scheduleOverride,
    Color? newsAccent,
    Color? surfaceElevated,
    Color? lessonCardFill,
    Color? lessonCardBorder,
    Color? lessonCardTitle,
    Color? lessonCardSubtitle,
    Color? emptySlotFill,
    Color? emptySlotBorder,
    Color? emptySlotText,
    Color? subtleDivider,
    Color? mutedLabel,
    Color? dayHeadingText,
    Color? weekHeaderText,
    Color? lessonBadgeFill,
    Color? lessonBadgeText,
  }) {
    return AppPalette(
      noteBackground: noteBackground ?? this.noteBackground,
      noteForeground: noteForeground ?? this.noteForeground,
      noteBorder: noteBorder ?? this.noteBorder,
      notificationIndicator:
          notificationIndicator ?? this.notificationIndicator,
      scheduleHasLessons: scheduleHasLessons ?? this.scheduleHasLessons,
      scheduleEvenWeek: scheduleEvenWeek ?? this.scheduleEvenWeek,
      scheduleOddWeek: scheduleOddWeek ?? this.scheduleOddWeek,
      scheduleNoLessonsInMonth:
          scheduleNoLessonsInMonth ?? this.scheduleNoLessonsInMonth,
      scheduleNoLessonsOutMonth:
          scheduleNoLessonsOutMonth ?? this.scheduleNoLessonsOutMonth,
      scheduleSelected: scheduleSelected ?? this.scheduleSelected,
      scheduleSelectedText: scheduleSelectedText ?? this.scheduleSelectedText,
      scheduleTodayRing: scheduleTodayRing ?? this.scheduleTodayRing,
      scheduleInMonthText: scheduleInMonthText ?? this.scheduleInMonthText,
      scheduleOutMonthText: scheduleOutMonthText ?? this.scheduleOutMonthText,
      scheduleOverride: scheduleOverride ?? this.scheduleOverride,
      newsAccent: newsAccent ?? this.newsAccent,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      lessonCardFill: lessonCardFill ?? this.lessonCardFill,
      lessonCardBorder: lessonCardBorder ?? this.lessonCardBorder,
      lessonCardTitle: lessonCardTitle ?? this.lessonCardTitle,
      lessonCardSubtitle: lessonCardSubtitle ?? this.lessonCardSubtitle,
      emptySlotFill: emptySlotFill ?? this.emptySlotFill,
      emptySlotBorder: emptySlotBorder ?? this.emptySlotBorder,
      emptySlotText: emptySlotText ?? this.emptySlotText,
      subtleDivider: subtleDivider ?? this.subtleDivider,
      mutedLabel: mutedLabel ?? this.mutedLabel,
      dayHeadingText: dayHeadingText ?? this.dayHeadingText,
      weekHeaderText: weekHeaderText ?? this.weekHeaderText,
      lessonBadgeFill: lessonBadgeFill ?? this.lessonBadgeFill,
      lessonBadgeText: lessonBadgeText ?? this.lessonBadgeText,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      noteBackground:
          Color.lerp(noteBackground, other.noteBackground, t)!,
      noteForeground:
          Color.lerp(noteForeground, other.noteForeground, t)!,
      noteBorder: Color.lerp(noteBorder, other.noteBorder, t)!,
      notificationIndicator: Color.lerp(
          notificationIndicator, other.notificationIndicator, t)!,
      scheduleHasLessons: Color.lerp(
          scheduleHasLessons, other.scheduleHasLessons, t)!,
      scheduleEvenWeek:
          Color.lerp(scheduleEvenWeek, other.scheduleEvenWeek, t)!,
      scheduleOddWeek:
          Color.lerp(scheduleOddWeek, other.scheduleOddWeek, t)!,
      scheduleNoLessonsInMonth: Color.lerp(
          scheduleNoLessonsInMonth, other.scheduleNoLessonsInMonth, t)!,
      scheduleNoLessonsOutMonth: Color.lerp(
          scheduleNoLessonsOutMonth, other.scheduleNoLessonsOutMonth, t)!,
      scheduleSelected:
          Color.lerp(scheduleSelected, other.scheduleSelected, t)!,
      scheduleSelectedText: Color.lerp(
          scheduleSelectedText, other.scheduleSelectedText, t)!,
      scheduleTodayRing:
          Color.lerp(scheduleTodayRing, other.scheduleTodayRing, t)!,
      scheduleInMonthText: Color.lerp(
          scheduleInMonthText, other.scheduleInMonthText, t)!,
      scheduleOutMonthText: Color.lerp(
          scheduleOutMonthText, other.scheduleOutMonthText, t)!,
      scheduleOverride:
          Color.lerp(scheduleOverride, other.scheduleOverride, t)!,
      newsAccent: Color.lerp(newsAccent, other.newsAccent, t)!,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      lessonCardFill: Color.lerp(lessonCardFill, other.lessonCardFill, t)!,
      lessonCardBorder:
          Color.lerp(lessonCardBorder, other.lessonCardBorder, t)!,
      lessonCardTitle:
          Color.lerp(lessonCardTitle, other.lessonCardTitle, t)!,
      lessonCardSubtitle: Color.lerp(
          lessonCardSubtitle, other.lessonCardSubtitle, t)!,
      emptySlotFill: Color.lerp(emptySlotFill, other.emptySlotFill, t)!,
      emptySlotBorder:
          Color.lerp(emptySlotBorder, other.emptySlotBorder, t)!,
      emptySlotText: Color.lerp(emptySlotText, other.emptySlotText, t)!,
      subtleDivider: Color.lerp(subtleDivider, other.subtleDivider, t)!,
      mutedLabel: Color.lerp(mutedLabel, other.mutedLabel, t)!,
      dayHeadingText:
          Color.lerp(dayHeadingText, other.dayHeadingText, t)!,
      weekHeaderText:
          Color.lerp(weekHeaderText, other.weekHeaderText, t)!,
      lessonBadgeFill:
          Color.lerp(lessonBadgeFill, other.lessonBadgeFill, t)!,
      lessonBadgeText:
          Color.lerp(lessonBadgeText, other.lessonBadgeText, t)!,
    );
  }
}
