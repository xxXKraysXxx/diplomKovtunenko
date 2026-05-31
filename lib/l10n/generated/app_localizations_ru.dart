// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Расписание КТИ';

  @override
  String get navNews => 'Новости';

  @override
  String get navNotifications => 'Уведомления';

  @override
  String get navSchedule => 'Расписание';

  @override
  String get navSettings => 'Настройки';

  @override
  String get navAdmin => 'Админ';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonApply => 'Применить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonCopy => 'Копировать';

  @override
  String get commonCopied => 'Скопировано';

  @override
  String get commonOpen => 'Открыть';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get commonSend => 'Отправить';

  @override
  String get commonOk => 'Ок';

  @override
  String get commonNext => 'Далее';

  @override
  String get commonError => 'Ошибка';

  @override
  String commonErrorWith(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get commonSearch => 'Поиск';

  @override
  String get commonClear => 'Очистить';

  @override
  String get commonReset => 'Сбросить';

  @override
  String get commonNothingFound => 'Ничего не найдено';

  @override
  String get sessionExpired => 'Сессия истекла. Войдите снова.';

  @override
  String get sessionExpiredLogin => 'Войти';

  @override
  String get connectionErrorTitle => 'Что-то пошло не так';

  @override
  String get connectionErrorRetry => 'Повторить';

  @override
  String get connectionErrorLoginAgain => 'Войти заново';

  @override
  String get connectionErrorOffline =>
      'Нет соединения с сервером. Проверьте интернет.';

  @override
  String get connectionErrorServer => 'Сервер не отвечает. Попробуйте позже.';

  @override
  String get connectionErrorTimeout =>
      'Превышено время ожидания. Попробуйте ещё раз.';

  @override
  String get connectionErrorUnknown => 'Произошла ошибка.';

  @override
  String get connectionErrorDetails => 'Подробнее';

  @override
  String get offlineBannerMessage =>
      'Нет соединения с сервером — показаны последние данные';

  @override
  String get offlineBannerRetry => 'Повторить';

  @override
  String get offlineBannerDismiss => 'Скрыть';

  @override
  String get authBadCredentials => 'Введите логин и пароль';

  @override
  String get authConnectionTimeout =>
      'Тайм-аут соединения с сервером — проблема со связью или сервера на тех работах';

  @override
  String get authNetworkError => 'Ошибка сети';

  @override
  String get loginTitle => 'Вход';

  @override
  String get loginLabel => 'Логин';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get loginSubmit => 'Войти';

  @override
  String get loginContinueAsGuest => 'Продолжить как гость';

  @override
  String get loginRegisterHint =>
      'Нет аккаунта? Зарегистрироваться как студент';

  @override
  String get registerTitle => 'Регистрация';

  @override
  String get registerLoginEmpty => 'Введите логин';

  @override
  String get registerPasswordTooShort =>
      'Пароль должен быть не короче 6 символов';

  @override
  String get registerPasswordsMismatch => 'Пароли не совпадают';

  @override
  String get registerGroupRequired => 'Выберите группу';

  @override
  String get registerRepeatPassword => 'Повторите пароль';

  @override
  String get registerSubmit => 'Зарегистрироваться';

  @override
  String get registerHaveAccount => 'Есть аккаунт? Войти';

  @override
  String get registerGroupLabel => 'Группа';

  @override
  String registerGroupsLoadError(String message) {
    return 'Не удалось загрузить группы: $message';
  }

  @override
  String get newsTitle => 'Новости';

  @override
  String get newsEmpty => 'Пока нет новостей';

  @override
  String get newsOpenInBrowser => 'Открыть в браузере';

  @override
  String get newsOpenOnSource => 'Открыть на ncti.ru';

  @override
  String get newsOfflineUnavailable =>
      'Статья ещё не подготовлена к офлайн-просмотру.';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsMarkAllReadTooltip => 'Прочитать все';

  @override
  String get notificationsSend => 'Отправить';

  @override
  String get notificationsEmpty => 'Нет уведомлений';

  @override
  String get notificationsMarkAllConfirmTitle => 'Прочитать все?';

  @override
  String get notificationsMarkAllConfirmBody =>
      'Пометить все уведомления как прочитанные?';

  @override
  String get notificationsMarkAllConfirm => 'Прочитать';

  @override
  String notificationsLoadError(String message) {
    return 'Не удалось загрузить уведомления:\n$message';
  }

  @override
  String get notificationsScopeGlobal => 'ГЛОБАЛ';

  @override
  String get notificationsSent => 'Отправлено';

  @override
  String get notificationsComposeTitle => 'Новое уведомление';

  @override
  String get notificationsRecipients => 'Кому';

  @override
  String get notificationsGlobal => 'Глобально';

  @override
  String get notificationsByGroup => 'По группам';

  @override
  String get notificationsGroups => 'Группы';

  @override
  String get notificationsGroupSearch => 'Поиск группы';

  @override
  String get notificationsGroupsLoadError => 'Не удалось загрузить группы';

  @override
  String get notificationsMessage => 'Сообщение';

  @override
  String get notificationsMessageHint => 'Что сообщить…';

  @override
  String get notificationsLinkDate => 'Привязать к дате (необязательно)';

  @override
  String get notificationsPickDate => 'Выбрать дату';

  @override
  String notificationsLinkedDate(String date) {
    return 'Дата: $date';
  }

  @override
  String get notificationsLinkedDateHint =>
      'Заметка появится у получателей в календаре на этот день.';

  @override
  String get notificationsServerError => 'Ошибка сервера';

  @override
  String get notificationsRelJustNow => 'только что';

  @override
  String notificationsRelMinutes(int count) {
    return '$count мин назад';
  }

  @override
  String notificationsRelHours(int count) {
    return '$count ч назад';
  }

  @override
  String notificationsRelDays(int count) {
    return '$count дн назад';
  }

  @override
  String get notifPrefsScheduleChanges => 'Изменения в расписании';

  @override
  String get notifPrefsNews => 'Новости';

  @override
  String get notifPrefsMessages => 'Сообщения';

  @override
  String get notifPrefsMinigameCalls => 'Вызовы в минииграх';

  @override
  String get changePasswordTitle => 'Смена пароля';

  @override
  String get roleAdmin => 'админ';

  @override
  String get roleTeacher => 'преподаватель';

  @override
  String get roleStudent => 'студент';

  @override
  String get roleSystem => 'система';

  @override
  String get roleChipAdmin => 'АДМИН';

  @override
  String get roleChipTeacher => 'ПРЕПОД.';

  @override
  String get roleChipStudent => 'СТУДЕНТ';

  @override
  String get roleChipSystem => 'СИСТЕМА';

  @override
  String get notificationsAdminShowAllOn =>
      'Показаны все уведомления (включая групповые). Нажмите, чтобы скрыть групповые.';

  @override
  String get notificationsAdminShowAllOff =>
      'Показаны только глобальные. Нажмите, чтобы включить групповые.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAccount => 'Аккаунт';

  @override
  String get settingsNotLoggedIn => 'Вы не вошли';

  @override
  String get settingsLoginToSync => 'Войдите, чтобы синхронизировать заметки';

  @override
  String get settingsLogin => 'Войти';

  @override
  String get settingsLogout => 'Выйти';

  @override
  String get settingsChangePassword => 'Сменить пароль';

  @override
  String get settingsPushTitle => 'Push-уведомления';

  @override
  String get settingsPrefNews => 'Новости';

  @override
  String get settingsPrefAnnouncements =>
      'Уведомления от преподавателей и администрации';

  @override
  String get settingsPrefScheduleChanges => 'Изменения в расписании';

  @override
  String get settingsPrefTokenPending => 'Ждём регистрации устройства…';

  @override
  String get settingsInterface => 'Интерфейс';

  @override
  String get settingsHideEmptySlots => 'Скрывать пустые пары';

  @override
  String get settingsShowLessonProgress => 'Прогресс текущей пары';

  @override
  String get settingsShowWeekCarousel => 'Лента дней вместо сетки';

  @override
  String get settingsScheduleView => 'Вид расписания';

  @override
  String get settingsScheduleViewGrid => 'Сетка';

  @override
  String get settingsScheduleViewDayStrip => 'Лента дней';

  @override
  String get settingsScheduleViewWeekList => 'По неделям';

  @override
  String get settingsDayColoring => 'Раскраска дней с парами';

  @override
  String get settingsDayColoringAuto => 'Авто';

  @override
  String get settingsDayColoringHasLessons => 'Монотон';

  @override
  String get settingsDayColoringEvenOdd => 'Чёт. / Нечёт.';

  @override
  String get settingsDynamicColor => 'Цвета системы';

  @override
  String get settingsDynamicColorHint => 'Material You (Android 12+)';

  @override
  String get settingsThemeSeedTitle => 'Цвет темы';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeSystem => 'Система';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageSystem => 'Система';

  @override
  String get settingsLanguageRu => 'Русский';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String settingsVersion(String version, String build) {
    return 'Версия $version (сборка $build)';
  }

  @override
  String get settingsVersionLoading => 'Версия …';

  @override
  String get settingsClearCache => 'Очистить кеш';

  @override
  String get settingsClearCacheHint =>
      'Сбросить локальный кеш расписания и фильтр. Авторизация сохранится.';

  @override
  String get settingsClearCacheConfirmTitle => 'Очистить кеш?';

  @override
  String get settingsClearCacheConfirmBody =>
      'Локальный кеш расписания и сохранённый фильтр будут удалены. Авторизация сохранится.';

  @override
  String get settingsClearCacheDone => 'Кеш очищен. Перезапустите приложение.';

  @override
  String get settingsAccentTitle => 'Цвет моих уведомлений';

  @override
  String get settingsAccentHint =>
      'Отмечает ваши уведомления и прикреплённые заметки.';

  @override
  String get settingsAccentPick => 'Выбрать цвет…';

  @override
  String get settingsAccentDefault => 'По умолчанию';

  @override
  String get settingsChangePasswordTitle => 'Сменить пароль';

  @override
  String get settingsChangePasswordHint =>
      'Введите текущий пароль и новый (>=6 символов, совпадают)';

  @override
  String get settingsChangePasswordCurrent => 'Текущий пароль';

  @override
  String get settingsChangePasswordNew => 'Новый пароль';

  @override
  String get settingsChangePasswordRepeat => 'Повторите новый пароль';

  @override
  String get settingsChangePasswordSubmit => 'Сменить';

  @override
  String get settingsChangePasswordDone => 'Пароль изменён';

  @override
  String get settingsDebugTitle => 'Отладка';

  @override
  String get settingsDebugTestTime => 'Тестовое время';

  @override
  String get settingsDebugConnState => 'Состояние соединения';

  @override
  String get settingsDebugOnline => 'онлайн';

  @override
  String get settingsDebugOffline => 'оффлайн';

  @override
  String get settingsDebugNoteQueue => 'Очередь заметок';

  @override
  String get settingsDebugQueueEmpty => 'пусто';

  @override
  String settingsDebugQueueOps(int count) {
    return '$count оп.';
  }

  @override
  String get settingsDebugLastSync => 'Последняя синхронизация';

  @override
  String get settingsDebugShowFcm => 'Показать FCM токен';

  @override
  String get settingsDebugForceSync => 'Принудительная синхронизация';

  @override
  String get settingsDebugClearStorage => 'Очистить локальное хранилище';

  @override
  String get settingsDebugDatePickHelp => 'Дата';

  @override
  String get settingsDebugTimePickHelp => 'Время';

  @override
  String get settingsDebugFcmTitle => 'FCM токен';

  @override
  String get settingsDebugFcmUnavailable => '(токен недоступен)';

  @override
  String settingsDebugFcmError(String message) {
    return '(ошибка: $message)';
  }

  @override
  String get settingsDebugQueueEmptyMsg => 'Очередь пуста';

  @override
  String settingsDebugQueueNotSent(int count) {
    return 'Не отправлено: $count';
  }

  @override
  String get settingsDebugClearConfirmTitle => 'Очистить хранилище?';

  @override
  String get settingsDebugClearConfirmBody =>
      'Будут удалены локальные настройки, очередь заметок, кэш и тема. Авторизация сохранится.';

  @override
  String get settingsDebugClearDone =>
      'Хранилище очищено. Перезапустите приложение.';

  @override
  String get settingsDebugWidgetLog => 'Лог виджета';

  @override
  String get settingsDebugWidgetLogEmpty => 'Лог пуст или файл не существует.';

  @override
  String get settingsDebugWidgetLogUnavailable =>
      'Внешнее хранилище недоступно.';

  @override
  String get settingsDebugPalette => 'Палитра (отладка)';

  @override
  String get paletteDebugTitle => 'Отладка палитры';

  @override
  String get paletteDebugHint =>
      'Нажмите на образец, чтобы временно переопределить токен. Изменения применяются вживую.';

  @override
  String get paletteDebugReset => 'Сбросить';

  @override
  String get paletteDebugResetDone => 'Все переопределения сброшены';

  @override
  String get paletteDebugSeedLabel => 'Основной цвет';

  @override
  String get paletteDebugInspectorLabel => 'Инспектор регионов';

  @override
  String get paletteDebugClearOverrideTooltip => 'Сбросить переопределение';

  @override
  String get colorPickerTitle => 'Выберите цвет';

  @override
  String get colorPickerPrimary => 'Основные';

  @override
  String get colorPickerWheel => 'Колесо';

  @override
  String get colorPickerPrimaryHeading => 'Основные цвета';

  @override
  String get colorPickerShade => 'Оттенок';

  @override
  String get colorPickerCustom => 'Произвольный цвет';

  @override
  String get colorPickerCopied => 'Скопировано в буфер обмена';

  @override
  String get pushRationaleTitle => 'Уведомления';

  @override
  String get pushRationaleBodyWeb =>
      'Разрешите уведомления, чтобы получать сообщения от преподавателей и узнавать об изменениях в расписании.\n\nПосле нажатия «Разрешить» браузер покажет системный запрос.';

  @override
  String get pushRationaleBodyMobile =>
      'Включите уведомления, чтобы получать сообщения от преподавателей и узнавать об изменениях в расписании.';

  @override
  String get pushRationaleLater => 'Позже';

  @override
  String get pushRationaleNotNow => 'Не сейчас';

  @override
  String get pushRationaleAllow => 'Разрешить';

  @override
  String get pushSnackbarOpen => 'Открыть';

  @override
  String get pushPermissionBlocked => 'Уведомления заблокированы в браузере';

  @override
  String get pushPermissionBlockedMobile =>
      'Уведомления заблокированы в настройках системы';

  @override
  String get pushPermissionBlockedHelpTitle => 'Как разблокировать';

  @override
  String get pushPermissionBlockedHelpBodyWeb =>
      'Откройте настройки сайта в браузере (обычно значок замка в адресной строке), разрешите уведомления для этого сайта и перезагрузите страницу.';

  @override
  String get pushPermissionBlockedHelpBodyMobile =>
      'Откройте системные настройки приложения и разрешите уведомления, затем вернитесь.';

  @override
  String get pushPermissionDeniedSnack => 'Разрешение не получено';

  @override
  String get pushPermissionBlockedHelpOk => 'Понятно';

  @override
  String noteQueueSaveError(String message) {
    return 'Не удалось сохранить заметку: $message';
  }

  @override
  String timeMinutesShort(int count) {
    return '$count мин';
  }

  @override
  String timeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часов',
      few: '$count часа',
      one: '$count час',
    );
    return '$_temp0';
  }

  @override
  String timeHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours часов',
      few: '$hours часа',
      one: '$hours час',
    );
    return '$_temp0 $minutes мин';
  }

  @override
  String get scheduleTitle => 'Расписание';

  @override
  String get scheduleReturnToToday => 'Сегодня';

  @override
  String get scheduleFilterGroup => 'Группа';

  @override
  String get scheduleFilterTeacher => 'Преподаватель';

  @override
  String get scheduleFilterRoom => 'Кабинет';

  @override
  String get scheduleFilterGroupPick => 'Выберите группу';

  @override
  String get scheduleFilterTeacherPick => 'Выберите преподавателя';

  @override
  String get scheduleFilterRoomPick => 'Выберите кабинет';

  @override
  String get scheduleHasLessons => 'Есть занятия';

  @override
  String get scheduleNoLessons => 'Нет занятий';

  @override
  String get scheduleWeekOdd => 'Нечётная неделя';

  @override
  String get scheduleWeekEven => 'Чётная неделя';

  @override
  String get scheduleNoFilterPicked =>
      'Выберите группу, преподавателя или кабинет';

  @override
  String get scheduleNoLessonsOnDay => 'Нет занятий на этот день';

  @override
  String get scheduleNoLessonsOnDayShort => 'Нет занятий';

  @override
  String get scheduleNoDataForWeek => 'Нет данных за эту неделю';

  @override
  String get scheduleTodayBadge => 'Сегодня';

  @override
  String get scheduleWeekPrev => 'Предыдущая';

  @override
  String get scheduleWeekCurrent => 'Текущая';

  @override
  String get scheduleWeekNext => 'Следующая';

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
    return '$fromDay $month – $toDay $month, $parity';
  }

  @override
  String weekListRangeCrossMonth(
      int fromDay, String fromMonth, int toDay, String toMonth, String parity) {
    return '$fromDay $fromMonth – $toDay $toMonth, $parity';
  }

  @override
  String weekListRangeCrossYear(int fromDay, String fromMonth, int fromYear,
      int toDay, String toMonth, int toYear, String parity) {
    return '$fromDay $fromMonth $fromYear – $toDay $toMonth $toYear, $parity';
  }

  @override
  String get weekListParityEven => 'чётная';

  @override
  String get weekListParityOdd => 'нечётная';

  @override
  String scheduleDayHeader(int day, String month, int year, String weekday) {
    return '$day $month $year, $weekday';
  }

  @override
  String get scheduleNowOngoing => 'Идёт сейчас';

  @override
  String scheduleNowEndsInMin(int count) {
    return 'Заканчивается через $count мин';
  }

  @override
  String scheduleNowOngoingUntil(String timeLeft) {
    return 'Идёт сейчас · до конца $timeLeft';
  }

  @override
  String scheduleStartsIn(String timeLeft) {
    return 'Начнётся через $timeLeft';
  }

  @override
  String get scheduleNow => 'Сейчас';

  @override
  String schedulePairOrdinal(int ordinal) {
    return 'Пара $ordinal';
  }

  @override
  String scheduleOrdinalPair(int ordinal) {
    return '$ordinal пара';
  }

  @override
  String scheduleSubgroup(String value) {
    return 'подгруппа $value';
  }

  @override
  String get scheduleOverrideIndicator => 'Изменено';

  @override
  String get scheduleNoteLabel => 'Заметка';

  @override
  String get scheduleNoteOfflineHint =>
      'Заметка будет сохранена при подключении к интернету';

  @override
  String get schedulePinnedNoteSingle => 'Закреплённая заметка';

  @override
  String get schedulePinnedNoteMany => 'Закреплённые заметки';

  @override
  String get scheduleDeleteNoteConfirmTitle => 'Удалить заметку?';

  @override
  String get scheduleDeleteNoteConfirmBody =>
      'Закреплённая заметка будет удалена у всех получателей.';

  @override
  String scheduleRelToday(String time) {
    return 'сегодня в $time';
  }

  @override
  String scheduleRelYesterday(String time) {
    return 'вчера в $time';
  }

  @override
  String scheduleRelDaysAgo(int count) {
    return '$count дн назад';
  }

  @override
  String scheduleNoteTime(int day, String month, String time) {
    return 'Время: $day $month, $time';
  }

  @override
  String get scheduleOfflineBanner => 'Нет подключения. Работаем из кэша.';

  @override
  String scheduleNoteForDay(String day) {
    return 'Заметка на $day';
  }

  @override
  String get scheduleNoteHint => 'Что-то важное на этот день…';

  @override
  String scheduleLoadError(String message) {
    return 'Не удалось загрузить расписание:\n$message';
  }

  @override
  String get scheduleNoConnection => 'Нет соединения с сервером';

  @override
  String get monthShortJan => 'янв';

  @override
  String get monthShortFeb => 'фев';

  @override
  String get monthShortMar => 'мар';

  @override
  String get monthShortApr => 'апр';

  @override
  String get monthShortMay => 'май';

  @override
  String get monthShortJun => 'июн';

  @override
  String get monthShortJul => 'июл';

  @override
  String get monthShortAug => 'авг';

  @override
  String get monthShortSep => 'сен';

  @override
  String get monthShortOct => 'окт';

  @override
  String get monthShortNov => 'ноя';

  @override
  String get monthShortDec => 'дек';

  @override
  String get monthGenJan => 'января';

  @override
  String get monthGenFeb => 'февраля';

  @override
  String get monthGenMar => 'марта';

  @override
  String get monthGenApr => 'апреля';

  @override
  String get monthGenMay => 'мая';

  @override
  String get monthGenJun => 'июня';

  @override
  String get monthGenJul => 'июля';

  @override
  String get monthGenAug => 'августа';

  @override
  String get monthGenSep => 'сентября';

  @override
  String get monthGenOct => 'октября';

  @override
  String get monthGenNov => 'ноября';

  @override
  String get monthGenDec => 'декабря';

  @override
  String get monthLongJan => 'Январь';

  @override
  String get monthLongFeb => 'Февраль';

  @override
  String get monthLongMar => 'Март';

  @override
  String get monthLongApr => 'Апрель';

  @override
  String get monthLongMay => 'Май';

  @override
  String get monthLongJun => 'Июнь';

  @override
  String get monthLongJul => 'Июль';

  @override
  String get monthLongAug => 'Август';

  @override
  String get monthLongSep => 'Сентябрь';

  @override
  String get monthLongOct => 'Октябрь';

  @override
  String get monthLongNov => 'Ноябрь';

  @override
  String get monthLongDec => 'Декабрь';

  @override
  String get weekdayShortMon => 'Пн';

  @override
  String get weekdayShortTue => 'Вт';

  @override
  String get weekdayShortWed => 'Ср';

  @override
  String get weekdayShortThu => 'Чт';

  @override
  String get weekdayShortFri => 'Пт';

  @override
  String get weekdayShortSat => 'Сб';

  @override
  String get weekdayShortSun => 'Вс';

  @override
  String get weekdayLongMon => 'понедельник';

  @override
  String get weekdayLongTue => 'вторник';

  @override
  String get weekdayLongWed => 'среда';

  @override
  String get weekdayLongThu => 'четверг';

  @override
  String get weekdayLongFri => 'пятница';

  @override
  String get weekdayLongSat => 'суббота';

  @override
  String get weekdayLongSun => 'воскресенье';

  @override
  String scheduleSelectedDate(int day, String month, String weekday) {
    return '$day $month, $weekday';
  }

  @override
  String scheduleMonthHeader(String month, int year) {
    return '$month $year';
  }

  @override
  String get adminTitle => 'Администрирование';

  @override
  String get adminTabUsers => 'Пользователи';

  @override
  String get adminTabCreateTeacher => 'Создать препод.';

  @override
  String get adminTabCreateAdmin => 'Создать админа';

  @override
  String get adminTabPushRights => 'Push-права';

  @override
  String get adminTabActivity => 'Активность';

  @override
  String get adminTabSettings => 'Настройки';

  @override
  String get adminSearchLogin => 'Поиск по логину';

  @override
  String get adminRoleAdmins => 'Админы';

  @override
  String get adminRoleTeachers => 'Преподаватели';

  @override
  String get adminRoleStudents => 'Студенты';

  @override
  String get adminUsersEmpty => 'Нет пользователей';

  @override
  String get adminRecordDeleted => 'Запись удалена';

  @override
  String get adminSelfMarker => 'вы';

  @override
  String adminLastActive(String timestamp) {
    return 'активн.: $timestamp';
  }

  @override
  String get adminActions => 'Действия';

  @override
  String get adminResetPassword => 'Сбросить пароль';

  @override
  String adminGroupPrefix(String name) {
    return 'группа $name';
  }

  @override
  String get adminResetOwnConfirmTitle => 'Сбросить пароль себе?';

  @override
  String get adminResetOwnConfirmBody =>
      'Вы сбрасываете пароль собственному аккаунту. После этого нужно будет войти заново. Продолжить?';

  @override
  String get adminDeleteUserConfirmTitle => 'Удалить пользователя?';

  @override
  String adminDeleteUserConfirmBody(String login, String role) {
    return 'Удалить «$login» ($role)?';
  }

  @override
  String adminPasswordUpdatedFor(String login) {
    return 'Пароль обновлён для $login';
  }

  @override
  String adminResetPasswordFor(String login) {
    return 'Сбросить пароль: $login';
  }

  @override
  String get adminNewPassword => 'Новый пароль';

  @override
  String get adminConfirmPassword => 'Подтвердите пароль';

  @override
  String get adminCreateTeacherFormHint =>
      'Заполните логин, пароль (>=6) и выберите преподавателя';

  @override
  String adminCreatedNotice(String login) {
    return 'Создано: $login';
  }

  @override
  String get adminLoginField => 'Логин';

  @override
  String get adminPasswordField => 'Пароль';

  @override
  String adminLoadError(String message) {
    return 'Ошибка загрузки: $message';
  }

  @override
  String get adminTeacherField => 'Преподаватель';

  @override
  String get adminCreateTeacherTitle => 'Создать преподавателя';

  @override
  String get adminCreateAdminTitle => 'Создать администратора';

  @override
  String get adminCreateAdminRequired => 'Логин и пароль (>=6) обязательны';

  @override
  String adminCreateAdminCreated(String login) {
    return 'Администратор создан: $login';
  }

  @override
  String get adminPushHint =>
      'Можно отключить возможность рассылки уведомлений для отдельного преподавателя.';

  @override
  String get adminNoTeachers => 'Нет пользователей-преподавателей';

  @override
  String get adminTeacherUnlinked => 'преподаватель не привязан';

  @override
  String adminTeacherId(String id) {
    return 'препод. #$id';
  }

  @override
  String get adminCanPushLabel => 'Может отправлять уведомления';

  @override
  String get adminCanBroadcastGloballyLabel => 'Может отправлять всем';

  @override
  String get adminNotificationsTab => 'Уведомления';

  @override
  String adminAppSettingsError(String message) {
    return 'Ошибка загрузки: $message';
  }

  @override
  String get adminTeachersGlobalTitle =>
      'Преподаватели могут отправлять глобальные уведомления';

  @override
  String get adminTeachersGlobalHint =>
      'Если выключено, преподаватели рассылают только по группам';

  @override
  String get adminNewsScrapeTitle => 'Сбор новостей';

  @override
  String get adminNewsScrapeHint =>
      'Получить свежие новости с сайта колледжа прямо сейчас. Сбор также запускается автоматически по расписанию.';

  @override
  String get adminNewsScrapeButton => 'Запустить сбор новостей';

  @override
  String get adminNewsScrapeAccepted => 'Сбор новостей запущен';

  @override
  String get adminNewsScrapeBusy => 'Сбор уже идёт';

  @override
  String get adminNoData => 'данных нет';

  @override
  String adminStorageNotes(String size) {
    return 'заметки $size';
  }

  @override
  String adminStorageTotal(String size) {
    return 'всего $size';
  }

  @override
  String get adminActivityEmpty => 'Событий нет';

  @override
  String get adminActivity7d => 'За 7 дней';

  @override
  String get adminActivity30d => 'За 30 дней';

  @override
  String get adminActivityRegistrations => 'Регистраций';

  @override
  String get adminActivityFailedLogins => 'Неудачных входов';

  @override
  String get adminActivityPasswordResets => 'Сбросов паролей';

  @override
  String get adminActivitySentNotifications => 'Отправленных уведомлений';

  @override
  String get activityLabelRegister => 'Регистрация';

  @override
  String get activityLabelLogin => 'Вход';

  @override
  String get activityLabelLoginFailed => 'Неудачный вход';

  @override
  String get activityLabelPasswordChanged => 'Смена пароля';

  @override
  String get activityLabelPasswordResetByAdmin => 'Сброс пароля (админ)';

  @override
  String get activityLabelCreatedByAdmin => 'Создан админом';

  @override
  String get activityLabelUserDeleted => 'Удалён';

  @override
  String get activityLabelCanPushToggled => 'Push-права изменены';

  @override
  String get activityLabelCanBroadcastGloballyToggled =>
      'Права на глобальную рассылку изменены';

  @override
  String get activityLabelAccentColorSet => 'Выбран акцентный цвет';

  @override
  String get activityLabelNotifPrefsSet => 'Настройки уведомлений изменены';

  @override
  String get activityLabelLoggedOut => 'Выход';

  @override
  String get activityLabelAdminSettingUpdated =>
      'Настройка администратора изменена';

  @override
  String get activityLabelNewsScrapeTriggered => 'Запущен сбор новостей';

  @override
  String get activityLabelNotificationSent => 'Отправлено уведомление';

  @override
  String get activityLabelNotificationDeleted => 'Удалено уведомление';

  @override
  String get activityLabelDeviceRegistered => 'Пользователь вошёл';

  @override
  String get activityLabelDeviceUnregistered => 'Пользователь вышел';

  @override
  String get activityLabelDayNoteSet => 'Заметка сохранена';

  @override
  String get activityLabelDayNoteDeleted => 'Заметка удалена';

  @override
  String get activityFilterAll => 'Все';

  @override
  String get activityFilterUsers => 'Пользователи';

  @override
  String get activityFilterNotifications => 'Уведомления';

  @override
  String get activityFilterNotes => 'Заметки';

  @override
  String get activityFilterSecurity => 'Безопасность';

  @override
  String bytesB(String value) {
    return '$value Б';
  }

  @override
  String bytesKb(String value) {
    return '$value КБ';
  }

  @override
  String bytesMb(String value) {
    return '$value МБ';
  }

  @override
  String bytesGb(String value) {
    return '$value ГБ';
  }
}
