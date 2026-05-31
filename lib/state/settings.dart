import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HideEmptySlotsNotifier extends AsyncNotifier<bool> {
  static const _key = 'hideEmptySlots';

  // 1.3.5: default flipped to true. Existing users who set the toggle either
  // way still see their saved value (the prefs key is present so the
  // null-coalesce never fires); only fresh installs and users who never
  // touched the toggle on prior versions get hidden empty slots by default.
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    state = AsyncValue.data(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final hideEmptySlotsProvider =
    AsyncNotifierProvider<HideEmptySlotsNotifier, bool>(
  HideEmptySlotsNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const _key = 'themeMode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key));
  }

  Future<void> set(ThemeMode mode) async {
    state = AsyncValue.data(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }

  static ThemeMode _decode(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class DynamicColorEnabledNotifier extends AsyncNotifier<bool> {
  static const _key = 'dynamic_color_enabled';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    state = AsyncValue.data(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final dynamicColorEnabledProvider =
    AsyncNotifierProvider<DynamicColorEnabledNotifier, bool>(
  DynamicColorEnabledNotifier.new,
);

/// Device-local seed colour for the app theme ("Цвет темы"). `null` means
/// "use the shipped defaults" — the 1.2.1 product decision that defaults
/// are important. When Material You is on it wins over this, so the UI
/// greys the picker out but preserves whatever the user chose.
class ThemeSeedNotifier extends AsyncNotifier<String?> {
  static const _key = 'theme_seed_hex';

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> set(String? hex) async {
    state = AsyncValue.data(hex);
    final prefs = await SharedPreferences.getInstance();
    if (hex == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, hex);
    }
  }
}

final themeSeedProvider =
    AsyncNotifierProvider<ThemeSeedNotifier, String?>(ThemeSeedNotifier.new);

/// How the calendar grid colours each day.
///
/// `hasLessons` paints any day whose weekday appears in the shablon with a
/// single tint; days with no shablon entries on that weekday stay neutral.
/// `evenOdd` distinguishes shablon-even from shablon-odd weeks for users
/// who want the parity at a glance. `auto` inspects the shablon and picks
/// `evenOdd` when entries differ between parities, `hasLessons` otherwise.
enum DayColoringMode { auto, hasLessons, evenOdd }

class DayColoringModeNotifier extends AsyncNotifier<DayColoringMode> {
  static const _key = 'day_coloring_mode';

  @override
  Future<DayColoringMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key));
  }

  Future<void> set(DayColoringMode mode) async {
    state = AsyncValue.data(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }

  static DayColoringMode _decode(String? s) {
    switch (s) {
      case 'evenOdd':
        return DayColoringMode.evenOdd;
      case 'hasLessons':
        return DayColoringMode.hasLessons;
      case 'auto':
      default:
        return DayColoringMode.auto;
    }
  }

  static String _encode(DayColoringMode m) {
    switch (m) {
      case DayColoringMode.auto:
        return 'auto';
      case DayColoringMode.hasLessons:
        return 'hasLessons';
      case DayColoringMode.evenOdd:
        return 'evenOdd';
    }
  }
}

final dayColoringModeProvider =
    AsyncNotifierProvider<DayColoringModeNotifier, DayColoringMode>(
  DayColoringModeNotifier.new,
);

/// Persisted app locale. `null` means "follow system". Any other value is a
/// BCP-47 language code we support (currently "ru" or "en").
class LocaleNotifier extends AsyncNotifier<Locale?> {
  static const _key = 'app_locale';

  @override
  Future<Locale?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key));
  }

  Future<void> set(Locale? locale) async {
    state = AsyncValue.data(locale);
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }

  static Locale? _decode(String? code) {
    switch (code) {
      case 'ru':
        return const Locale('ru');
      case 'en':
        return const Locale('en');
      default:
        return null;
    }
  }
}

final localeProvider =
    AsyncNotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

/// Schedule view mode picked from Settings. `grid` is the historic 6-row
/// month grid; `dayStrip` is the 1.1.1 horizontal day carousel that
/// replaces the grid on narrow viewports; `weekList` is the 1.3.0
/// vertical week-list view.
///
/// Persisted under a new key (`schedule_view_mode`) but reads through to
/// the legacy `show_week_carousel` boolean on first launch so users who
/// flipped the day-strip toggle in 1.1.1+ keep their choice without a
/// re-pick. The legacy key is left in place untouched — never written
/// again — so a downgrade still finds it.
enum ScheduleViewMode { grid, dayStrip, weekList }

class ScheduleViewModeNotifier extends AsyncNotifier<ScheduleViewMode> {
  static const _key = 'schedule_view_mode';
  static const _legacyDayStripKey = 'show_week_carousel';

  @override
  Future<ScheduleViewMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    if (encoded != null) return _decode(encoded);
    final legacy = prefs.getBool(_legacyDayStripKey);
    if (legacy == true) return ScheduleViewMode.dayStrip;
    return ScheduleViewMode.grid;
  }

  Future<void> set(ScheduleViewMode mode) async {
    state = AsyncValue.data(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }

  static ScheduleViewMode _decode(String s) {
    switch (s) {
      case 'dayStrip':
        return ScheduleViewMode.dayStrip;
      case 'weekList':
        return ScheduleViewMode.weekList;
      case 'grid':
      default:
        return ScheduleViewMode.grid;
    }
  }

  static String _encode(ScheduleViewMode m) {
    switch (m) {
      case ScheduleViewMode.grid:
        return 'grid';
      case ScheduleViewMode.dayStrip:
        return 'dayStrip';
      case ScheduleViewMode.weekList:
        return 'weekList';
    }
  }
}

final scheduleViewModeProvider =
    AsyncNotifierProvider<ScheduleViewModeNotifier, ScheduleViewMode>(
  ScheduleViewModeNotifier.new,
);

/// 1.3.3: Toggle for the in-card progress fill on the currently-running
/// lesson (`Идёт сейчас`). The bar shaded the card from left→right showing
/// minutes elapsed in the period; some users found it visually noisy and
/// asked for a way off. Default ON preserves the historic behaviour for
/// existing installs.
class ShowLessonProgressNotifier extends AsyncNotifier<bool> {
  static const _key = 'show_lesson_progress';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    state = AsyncValue.data(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final showLessonProgressProvider =
    AsyncNotifierProvider<ShowLessonProgressNotifier, bool>(
  ShowLessonProgressNotifier.new,
);

/// Admin-only opt-in: include per-group notifications in the admin's own
/// notification feed. Off by default because admins otherwise see every
/// teacher's per-group blast and the feed becomes unreadable. Stored
/// locally — purely a personal viewing preference, not server state.
class AdminShowGroupNotificationsNotifier extends AsyncNotifier<bool> {
  static const _key = 'admin_show_group_notifications';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = AsyncValue.data(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final adminShowGroupNotificationsProvider =
    AsyncNotifierProvider<AdminShowGroupNotificationsNotifier, bool>(
  AdminShowGroupNotificationsNotifier.new,
);
