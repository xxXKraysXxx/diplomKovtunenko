// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KTI Schedule';

  @override
  String get navNews => 'News';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAdmin => 'Admin';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonSend => 'Send';

  @override
  String get commonOk => 'OK';

  @override
  String get commonNext => 'Next';

  @override
  String get commonError => 'Error';

  @override
  String commonErrorWith(String message) {
    return 'Error: $message';
  }

  @override
  String get commonSearch => 'Search';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonNothingFound => 'Nothing found';

  @override
  String get sessionExpired => 'Session expired. Please sign in again.';

  @override
  String get sessionExpiredLogin => 'Sign in';

  @override
  String get connectionErrorTitle => 'Something went wrong';

  @override
  String get connectionErrorRetry => 'Retry';

  @override
  String get connectionErrorLoginAgain => 'Try to sign in again';

  @override
  String get connectionErrorOffline =>
      'No connection to the server. Check your internet.';

  @override
  String get connectionErrorServer =>
      'The server isn\'t responding. Try again later.';

  @override
  String get connectionErrorTimeout => 'Request timed out. Try again.';

  @override
  String get connectionErrorUnknown => 'An error occurred.';

  @override
  String get connectionErrorDetails => 'Details';

  @override
  String get offlineBannerMessage => 'No connection — showing last data';

  @override
  String get offlineBannerRetry => 'Retry';

  @override
  String get offlineBannerDismiss => 'Dismiss';

  @override
  String get authBadCredentials => 'Enter a login and password';

  @override
  String get authConnectionTimeout =>
      'Connection timed out — network issue or server maintenance';

  @override
  String get authNetworkError => 'Network error';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginLabel => 'Login';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginContinueAsGuest => 'Continue as guest';

  @override
  String get loginRegisterHint => 'No account? Register as a student';

  @override
  String get registerTitle => 'Registration';

  @override
  String get registerLoginEmpty => 'Enter a login';

  @override
  String get registerPasswordTooShort =>
      'Password must be at least 6 characters';

  @override
  String get registerPasswordsMismatch => 'Passwords don\'t match';

  @override
  String get registerGroupRequired => 'Pick a group';

  @override
  String get registerRepeatPassword => 'Repeat password';

  @override
  String get registerSubmit => 'Register';

  @override
  String get registerHaveAccount => 'Have an account? Sign in';

  @override
  String get registerGroupLabel => 'Group';

  @override
  String registerGroupsLoadError(String message) {
    return 'Couldn\'t load groups: $message';
  }

  @override
  String get newsTitle => 'News';

  @override
  String get newsEmpty => 'No news yet';

  @override
  String get newsOpenInBrowser => 'Open in browser';

  @override
  String get newsOpenOnSource => 'Open on ncti.ru';

  @override
  String get newsOfflineUnavailable =>
      'This article isn\'t prepared for offline reading yet.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllReadTooltip => 'Mark all as read';

  @override
  String get notificationsSend => 'Send';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String get notificationsMarkAllConfirmTitle => 'Mark all as read?';

  @override
  String get notificationsMarkAllConfirmBody =>
      'Mark every notification as read?';

  @override
  String get notificationsMarkAllConfirm => 'Mark read';

  @override
  String notificationsLoadError(String message) {
    return 'Couldn\'t load notifications:\n$message';
  }

  @override
  String get notificationsScopeGlobal => 'GLOBAL';

  @override
  String get notificationsSent => 'Sent';

  @override
  String get notificationsComposeTitle => 'New notification';

  @override
  String get notificationsRecipients => 'Recipients';

  @override
  String get notificationsGlobal => 'Everyone';

  @override
  String get notificationsByGroup => 'By group';

  @override
  String get notificationsGroups => 'Groups';

  @override
  String get notificationsGroupSearch => 'Search groups';

  @override
  String get notificationsGroupsLoadError => 'Couldn\'t load groups';

  @override
  String get notificationsMessage => 'Message';

  @override
  String get notificationsMessageHint => 'What\'s the message…';

  @override
  String get notificationsLinkDate => 'Pin to date (optional)';

  @override
  String get notificationsPickDate => 'Pick date';

  @override
  String notificationsLinkedDate(String date) {
    return 'Date: $date';
  }

  @override
  String get notificationsLinkedDateHint =>
      'Recipients will see the note on their calendar on that day.';

  @override
  String get notificationsServerError => 'Server error';

  @override
  String get notificationsRelJustNow => 'just now';

  @override
  String notificationsRelMinutes(int count) {
    return '$count min ago';
  }

  @override
  String notificationsRelHours(int count) {
    return '${count}h ago';
  }

  @override
  String notificationsRelDays(int count) {
    return '${count}d ago';
  }

  @override
  String get notifPrefsScheduleChanges => 'Schedule changes';

  @override
  String get notifPrefsNews => 'News';

  @override
  String get notifPrefsMessages => 'Messages';

  @override
  String get notifPrefsMinigameCalls => 'Minigame calls';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get roleAdmin => 'admin';

  @override
  String get roleTeacher => 'teacher';

  @override
  String get roleStudent => 'student';

  @override
  String get roleSystem => 'system';

  @override
  String get roleChipAdmin => 'ADMIN';

  @override
  String get roleChipTeacher => 'TEACHER';

  @override
  String get roleChipStudent => 'STUDENT';

  @override
  String get roleChipSystem => 'SYSTEM';

  @override
  String get notificationsAdminShowAllOn =>
      'Showing all notifications (including per-group). Tap to hide per-group.';

  @override
  String get notificationsAdminShowAllOff =>
      'Showing only global. Tap to also show per-group.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsNotLoggedIn => 'Not signed in';

  @override
  String get settingsLoginToSync => 'Sign in to sync your notes';

  @override
  String get settingsLogin => 'Sign in';

  @override
  String get settingsLogout => 'Sign out';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsPushTitle => 'Push notifications';

  @override
  String get settingsPrefNews => 'News';

  @override
  String get settingsPrefAnnouncements =>
      'Announcements from teachers and staff';

  @override
  String get settingsPrefScheduleChanges => 'Schedule changes';

  @override
  String get settingsPrefTokenPending => 'Waiting for device registration…';

  @override
  String get settingsInterface => 'Interface';

  @override
  String get settingsHideEmptySlots => 'Hide empty slots';

  @override
  String get settingsShowLessonProgress => 'Lesson progress fill';

  @override
  String get settingsShowWeekCarousel => 'Day strip instead of grid';

  @override
  String get settingsScheduleView => 'Schedule view';

  @override
  String get settingsScheduleViewGrid => 'Grid';

  @override
  String get settingsScheduleViewDayStrip => 'Day strip';

  @override
  String get settingsScheduleViewWeekList => 'Weekly list';

  @override
  String get settingsDayColoring => 'Day coloring for class days';

  @override
  String get settingsDayColoringAuto => 'Auto';

  @override
  String get settingsDayColoringHasLessons => 'Monotone';

  @override
  String get settingsDayColoringEvenOdd => 'Even / odd';

  @override
  String get settingsDynamicColor => 'System colors';

  @override
  String get settingsDynamicColorHint => 'Material You (Android 12+)';

  @override
  String get settingsThemeSeedTitle => 'Theme color';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Follow system';

  @override
  String get settingsLanguageRu => 'Русский';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String settingsVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get settingsVersionLoading => 'Version …';

  @override
  String get settingsClearCache => 'Clear cache';

  @override
  String get settingsClearCacheHint =>
      'Reset the local schedule cache and saved filter. Sign-in stays.';

  @override
  String get settingsClearCacheConfirmTitle => 'Clear cache?';

  @override
  String get settingsClearCacheConfirmBody =>
      'The local schedule cache and saved filter will be deleted. Your sign-in stays.';

  @override
  String get settingsClearCacheDone => 'Cache cleared. Please restart the app.';

  @override
  String get settingsAccentTitle => 'My notifications color';

  @override
  String get settingsAccentHint => 'Marks your notifications and pinned notes.';

  @override
  String get settingsAccentPick => 'Pick a color…';

  @override
  String get settingsAccentDefault => 'Default';

  @override
  String get settingsChangePasswordTitle => 'Change password';

  @override
  String get settingsChangePasswordHint =>
      'Enter the current password and a new one (>=6 characters, matching)';

  @override
  String get settingsChangePasswordCurrent => 'Current password';

  @override
  String get settingsChangePasswordNew => 'New password';

  @override
  String get settingsChangePasswordRepeat => 'Repeat new password';

  @override
  String get settingsChangePasswordSubmit => 'Change';

  @override
  String get settingsChangePasswordDone => 'Password changed';

  @override
  String get settingsDebugTitle => 'Debug';

  @override
  String get settingsDebugTestTime => 'Test time';

  @override
  String get settingsDebugConnState => 'Connection state';

  @override
  String get settingsDebugOnline => 'online';

  @override
  String get settingsDebugOffline => 'offline';

  @override
  String get settingsDebugNoteQueue => 'Note queue';

  @override
  String get settingsDebugQueueEmpty => 'empty';

  @override
  String settingsDebugQueueOps(int count) {
    return '$count ops';
  }

  @override
  String get settingsDebugLastSync => 'Last sync';

  @override
  String get settingsDebugShowFcm => 'Show FCM token';

  @override
  String get settingsDebugForceSync => 'Force sync';

  @override
  String get settingsDebugClearStorage => 'Clear local storage';

  @override
  String get settingsDebugDatePickHelp => 'Date';

  @override
  String get settingsDebugTimePickHelp => 'Time';

  @override
  String get settingsDebugFcmTitle => 'FCM token';

  @override
  String get settingsDebugFcmUnavailable => '(token unavailable)';

  @override
  String settingsDebugFcmError(String message) {
    return '(error: $message)';
  }

  @override
  String get settingsDebugQueueEmptyMsg => 'Queue is empty';

  @override
  String settingsDebugQueueNotSent(int count) {
    return 'Not sent: $count';
  }

  @override
  String get settingsDebugClearConfirmTitle => 'Clear storage?';

  @override
  String get settingsDebugClearConfirmBody =>
      'Local settings, the note queue, cache and theme will be deleted. Your sign-in stays.';

  @override
  String get settingsDebugClearDone =>
      'Storage cleared. Please restart the app.';

  @override
  String get settingsDebugWidgetLog => 'Widget log';

  @override
  String get settingsDebugWidgetLogEmpty => 'Log is empty or missing.';

  @override
  String get settingsDebugWidgetLogUnavailable =>
      'External storage unavailable.';

  @override
  String get settingsDebugPalette => 'Palette (debug)';

  @override
  String get paletteDebugTitle => 'Palette debug';

  @override
  String get paletteDebugHint =>
      'Tap a swatch to override a token. Changes apply live.';

  @override
  String get paletteDebugReset => 'Reset';

  @override
  String get paletteDebugResetDone => 'All overrides cleared';

  @override
  String get paletteDebugSeedLabel => 'Main color';

  @override
  String get paletteDebugInspectorLabel => 'Region inspector';

  @override
  String get paletteDebugClearOverrideTooltip => 'Clear override';

  @override
  String get colorPickerTitle => 'Pick a color';

  @override
  String get colorPickerPrimary => 'Primary';

  @override
  String get colorPickerWheel => 'Wheel';

  @override
  String get colorPickerPrimaryHeading => 'Primary colors';

  @override
  String get colorPickerShade => 'Shade';

  @override
  String get colorPickerCustom => 'Custom color';

  @override
  String get colorPickerCopied => 'Copied to clipboard';

  @override
  String get pushRationaleTitle => 'Notifications';

  @override
  String get pushRationaleBodyWeb =>
      'Allow notifications to receive messages from teachers and stay on top of schedule changes.\n\nWhen you tap “Allow”, the browser will show the system prompt.';

  @override
  String get pushRationaleBodyMobile =>
      'Enable notifications to receive messages from teachers and stay on top of schedule changes.';

  @override
  String get pushRationaleLater => 'Later';

  @override
  String get pushRationaleNotNow => 'Not now';

  @override
  String get pushRationaleAllow => 'Allow';

  @override
  String get pushSnackbarOpen => 'Open';

  @override
  String get pushPermissionBlocked =>
      'Notifications blocked in browser settings';

  @override
  String get pushPermissionBlockedMobile =>
      'Notifications blocked in system settings';

  @override
  String get pushPermissionBlockedHelpTitle => 'How to unblock';

  @override
  String get pushPermissionBlockedHelpBodyWeb =>
      'Open your browser\'s site settings (usually the padlock icon in the address bar) and allow notifications for this site, then reload the page.';

  @override
  String get pushPermissionBlockedHelpBodyMobile =>
      'Open the system Settings for this app and allow Notifications, then come back.';

  @override
  String get pushPermissionDeniedSnack => 'Permission not granted';

  @override
  String get pushPermissionBlockedHelpOk => 'Got it';

  @override
  String noteQueueSaveError(String message) {
    return 'Couldn\'t save the note: $message';
  }

  @override
  String timeMinutesShort(int count) {
    return '$count min';
  }

  @override
  String timeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String timeHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '$hours hour',
    );
    return '$_temp0 $minutes min';
  }

  @override
  String get scheduleTitle => 'Schedule';

  @override
  String get scheduleReturnToToday => 'Today';

  @override
  String get scheduleFilterGroup => 'Group';

  @override
  String get scheduleFilterTeacher => 'Teacher';

  @override
  String get scheduleFilterRoom => 'Room';

  @override
  String get scheduleFilterGroupPick => 'Pick a group';

  @override
  String get scheduleFilterTeacherPick => 'Pick a teacher';

  @override
  String get scheduleFilterRoomPick => 'Pick a room';

  @override
  String get scheduleHasLessons => 'Has lessons';

  @override
  String get scheduleNoLessons => 'No lessons';

  @override
  String get scheduleWeekOdd => 'Odd week';

  @override
  String get scheduleWeekEven => 'Even week';

  @override
  String get scheduleNoFilterPicked => 'Pick a group, teacher, or room';

  @override
  String get scheduleNoLessonsOnDay => 'No lessons on this day';

  @override
  String get scheduleNoLessonsOnDayShort => 'No lessons';

  @override
  String get scheduleNoDataForWeek => 'No data for this week';

  @override
  String get scheduleTodayBadge => 'Today';

  @override
  String get scheduleWeekPrev => 'Previous';

  @override
  String get scheduleWeekCurrent => 'Current';

  @override
  String get scheduleWeekNext => 'Next';

  @override
  String scheduleWeekRange(int fromDay, int toDay, String month) {
    return '$fromDay–$toDay $month';
  }

  @override
  String scheduleWeekRangeCrossMonth(
      int fromDay, String fromMonth, int toDay, String toMonth) {
    return '$fromDay $fromMonth – $toDay $toMonth';
  }

  @override
  String weekListRangeSameMonth(
      int fromDay, int toDay, String month, String parity) {
    return '$month $fromDay – $month $toDay, $parity';
  }

  @override
  String weekListRangeCrossMonth(
      int fromDay, String fromMonth, int toDay, String toMonth, String parity) {
    return '$fromMonth $fromDay – $toMonth $toDay, $parity';
  }

  @override
  String weekListRangeCrossYear(int fromDay, String fromMonth, int fromYear,
      int toDay, String toMonth, int toYear, String parity) {
    return '$fromMonth $fromDay, $fromYear – $toMonth $toDay, $toYear, $parity';
  }

  @override
  String get weekListParityEven => 'even';

  @override
  String get weekListParityOdd => 'odd';

  @override
  String scheduleDayHeader(int day, String month, int year, String weekday) {
    return '$day $month $year, $weekday';
  }

  @override
  String get scheduleNowOngoing => 'In progress';

  @override
  String scheduleNowEndsInMin(int count) {
    return 'Ends in $count min';
  }

  @override
  String scheduleNowOngoingUntil(String timeLeft) {
    return 'In progress · $timeLeft left';
  }

  @override
  String scheduleStartsIn(String timeLeft) {
    return 'Starts in $timeLeft';
  }

  @override
  String get scheduleNow => 'Now';

  @override
  String schedulePairOrdinal(int ordinal) {
    return 'Class $ordinal';
  }

  @override
  String scheduleOrdinalPair(int ordinal) {
    return 'Class $ordinal';
  }

  @override
  String scheduleSubgroup(String value) {
    return 'subgroup $value';
  }

  @override
  String get scheduleOverrideIndicator => 'Modified';

  @override
  String get scheduleNoteLabel => 'Note';

  @override
  String get scheduleNoteOfflineHint =>
      'The note will sync once you\'re online';

  @override
  String get schedulePinnedNoteSingle => 'Pinned note';

  @override
  String get schedulePinnedNoteMany => 'Pinned notes';

  @override
  String get scheduleDeleteNoteConfirmTitle => 'Delete the note?';

  @override
  String get scheduleDeleteNoteConfirmBody =>
      'The pinned note will be deleted for every recipient.';

  @override
  String scheduleRelToday(String time) {
    return 'today at $time';
  }

  @override
  String scheduleRelYesterday(String time) {
    return 'yesterday at $time';
  }

  @override
  String scheduleRelDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String scheduleNoteTime(int day, String month, String time) {
    return 'Posted: $day $month, $time';
  }

  @override
  String get scheduleOfflineBanner => 'Offline. Showing cached data.';

  @override
  String scheduleNoteForDay(String day) {
    return 'Note for $day';
  }

  @override
  String get scheduleNoteHint => 'Anything important for this day…';

  @override
  String scheduleLoadError(String message) {
    return 'Couldn\'t load the schedule:\n$message';
  }

  @override
  String get scheduleNoConnection => 'No connection to the server';

  @override
  String get monthShortJan => 'Jan';

  @override
  String get monthShortFeb => 'Feb';

  @override
  String get monthShortMar => 'Mar';

  @override
  String get monthShortApr => 'Apr';

  @override
  String get monthShortMay => 'May';

  @override
  String get monthShortJun => 'Jun';

  @override
  String get monthShortJul => 'Jul';

  @override
  String get monthShortAug => 'Aug';

  @override
  String get monthShortSep => 'Sep';

  @override
  String get monthShortOct => 'Oct';

  @override
  String get monthShortNov => 'Nov';

  @override
  String get monthShortDec => 'Dec';

  @override
  String get monthGenJan => 'January';

  @override
  String get monthGenFeb => 'February';

  @override
  String get monthGenMar => 'March';

  @override
  String get monthGenApr => 'April';

  @override
  String get monthGenMay => 'May';

  @override
  String get monthGenJun => 'June';

  @override
  String get monthGenJul => 'July';

  @override
  String get monthGenAug => 'August';

  @override
  String get monthGenSep => 'September';

  @override
  String get monthGenOct => 'October';

  @override
  String get monthGenNov => 'November';

  @override
  String get monthGenDec => 'December';

  @override
  String get monthLongJan => 'January';

  @override
  String get monthLongFeb => 'February';

  @override
  String get monthLongMar => 'March';

  @override
  String get monthLongApr => 'April';

  @override
  String get monthLongMay => 'May';

  @override
  String get monthLongJun => 'June';

  @override
  String get monthLongJul => 'July';

  @override
  String get monthLongAug => 'August';

  @override
  String get monthLongSep => 'September';

  @override
  String get monthLongOct => 'October';

  @override
  String get monthLongNov => 'November';

  @override
  String get monthLongDec => 'December';

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String get weekdayLongMon => 'Monday';

  @override
  String get weekdayLongTue => 'Tuesday';

  @override
  String get weekdayLongWed => 'Wednesday';

  @override
  String get weekdayLongThu => 'Thursday';

  @override
  String get weekdayLongFri => 'Friday';

  @override
  String get weekdayLongSat => 'Saturday';

  @override
  String get weekdayLongSun => 'Sunday';

  @override
  String scheduleSelectedDate(int day, String month, String weekday) {
    return '$weekday, $month $day';
  }

  @override
  String scheduleMonthHeader(String month, int year) {
    return '$month $year';
  }

  @override
  String get adminTitle => 'Administration';

  @override
  String get adminTabUsers => 'Users';

  @override
  String get adminTabCreateTeacher => 'New teacher';

  @override
  String get adminTabCreateAdmin => 'New admin';

  @override
  String get adminTabPushRights => 'Push rights';

  @override
  String get adminTabActivity => 'Activity';

  @override
  String get adminTabSettings => 'Settings';

  @override
  String get adminSearchLogin => 'Search by login';

  @override
  String get adminRoleAdmins => 'Admins';

  @override
  String get adminRoleTeachers => 'Teachers';

  @override
  String get adminRoleStudents => 'Students';

  @override
  String get adminUsersEmpty => 'No users';

  @override
  String get adminRecordDeleted => 'Record deleted';

  @override
  String get adminSelfMarker => 'you';

  @override
  String adminLastActive(String timestamp) {
    return 'active: $timestamp';
  }

  @override
  String get adminActions => 'Actions';

  @override
  String get adminResetPassword => 'Reset password';

  @override
  String adminGroupPrefix(String name) {
    return 'group $name';
  }

  @override
  String get adminResetOwnConfirmTitle => 'Reset your own password?';

  @override
  String get adminResetOwnConfirmBody =>
      'You\'re resetting your own password. You\'ll need to sign in again afterwards. Continue?';

  @override
  String get adminDeleteUserConfirmTitle => 'Delete the user?';

  @override
  String adminDeleteUserConfirmBody(String login, String role) {
    return 'Delete “$login” ($role)?';
  }

  @override
  String adminPasswordUpdatedFor(String login) {
    return 'Password updated for $login';
  }

  @override
  String adminResetPasswordFor(String login) {
    return 'Reset password: $login';
  }

  @override
  String get adminNewPassword => 'New password';

  @override
  String get adminConfirmPassword => 'Confirm password';

  @override
  String get adminCreateTeacherFormHint =>
      'Fill in login, password (>=6 chars) and pick a teacher';

  @override
  String adminCreatedNotice(String login) {
    return 'Created: $login';
  }

  @override
  String get adminLoginField => 'Login';

  @override
  String get adminPasswordField => 'Password';

  @override
  String adminLoadError(String message) {
    return 'Load error: $message';
  }

  @override
  String get adminTeacherField => 'Teacher';

  @override
  String get adminCreateTeacherTitle => 'Create a teacher';

  @override
  String get adminCreateAdminTitle => 'Create an admin';

  @override
  String get adminCreateAdminRequired =>
      'Login and password (>=6) are required';

  @override
  String adminCreateAdminCreated(String login) {
    return 'Admin created: $login';
  }

  @override
  String get adminPushHint =>
      'You can disable broadcast permission for any specific teacher.';

  @override
  String get adminNoTeachers => 'No teacher users';

  @override
  String get adminTeacherUnlinked => 'teacher not linked';

  @override
  String adminTeacherId(String id) {
    return 'teacher #$id';
  }

  @override
  String get adminCanPushLabel => 'Can send notifications';

  @override
  String get adminCanBroadcastGloballyLabel => 'Can send globally';

  @override
  String get adminNotificationsTab => 'Notifications';

  @override
  String adminAppSettingsError(String message) {
    return 'Load error: $message';
  }

  @override
  String get adminTeachersGlobalTitle =>
      'Teachers can send global notifications';

  @override
  String get adminTeachersGlobalHint =>
      'If off, teachers can only send to groups';

  @override
  String get adminNewsScrapeTitle => 'News scrape';

  @override
  String get adminNewsScrapeHint =>
      'Fetch fresh news from the college site right now. A scrape also runs automatically on a schedule.';

  @override
  String get adminNewsScrapeButton => 'Run news scrape';

  @override
  String get adminNewsScrapeAccepted => 'News scrape started';

  @override
  String get adminNewsScrapeBusy => 'A scrape is already running';

  @override
  String get adminNoData => 'no data';

  @override
  String adminStorageNotes(String size) {
    return 'notes $size';
  }

  @override
  String adminStorageTotal(String size) {
    return 'total $size';
  }

  @override
  String get adminActivityEmpty => 'No events';

  @override
  String get adminActivity7d => 'Last 7 days';

  @override
  String get adminActivity30d => 'Last 30 days';

  @override
  String get adminActivityRegistrations => 'Registrations';

  @override
  String get adminActivityFailedLogins => 'Failed sign-ins';

  @override
  String get adminActivityPasswordResets => 'Password resets';

  @override
  String get adminActivitySentNotifications => 'Notifications sent';

  @override
  String get activityLabelRegister => 'Registration';

  @override
  String get activityLabelLogin => 'Sign in';

  @override
  String get activityLabelLoginFailed => 'Failed sign-in';

  @override
  String get activityLabelPasswordChanged => 'Password change';

  @override
  String get activityLabelPasswordResetByAdmin => 'Password reset (admin)';

  @override
  String get activityLabelCreatedByAdmin => 'Created by admin';

  @override
  String get activityLabelUserDeleted => 'Deleted';

  @override
  String get activityLabelCanPushToggled => 'Push rights changed';

  @override
  String get activityLabelCanBroadcastGloballyToggled =>
      'Global broadcast rights changed';

  @override
  String get activityLabelAccentColorSet => 'Accent color set';

  @override
  String get activityLabelNotifPrefsSet => 'Notification preferences updated';

  @override
  String get activityLabelLoggedOut => 'Sign out';

  @override
  String get activityLabelAdminSettingUpdated => 'Admin setting updated';

  @override
  String get activityLabelNewsScrapeTriggered => 'News scrape triggered';

  @override
  String get activityLabelNotificationSent => 'Notification sent';

  @override
  String get activityLabelNotificationDeleted => 'Notification deleted';

  @override
  String get activityLabelDeviceRegistered => 'User signed in';

  @override
  String get activityLabelDeviceUnregistered => 'User signed out';

  @override
  String get activityLabelDayNoteSet => 'Note saved';

  @override
  String get activityLabelDayNoteDeleted => 'Note deleted';

  @override
  String get activityFilterAll => 'All';

  @override
  String get activityFilterUsers => 'Users';

  @override
  String get activityFilterNotifications => 'Notifications';

  @override
  String get activityFilterNotes => 'Notes';

  @override
  String get activityFilterSecurity => 'Security';

  @override
  String bytesB(String value) {
    return '$value B';
  }

  @override
  String bytesKb(String value) {
    return '$value KB';
  }

  @override
  String bytesMb(String value) {
    return '$value MB';
  }

  @override
  String bytesGb(String value) {
    return '$value GB';
  }
}
