import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Расписание КТИ'**
  String get appTitle;

  /// No description provided for @navNews.
  ///
  /// In ru, this message translates to:
  /// **'Новости'**
  String get navNews;

  /// No description provided for @navNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get navNotifications;

  /// No description provided for @navSchedule.
  ///
  /// In ru, this message translates to:
  /// **'Расписание'**
  String get navSchedule;

  /// No description provided for @navSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get navSettings;

  /// No description provided for @navAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Админ'**
  String get navAdmin;

  /// No description provided for @commonCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get commonCancel;

  /// No description provided for @commonContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get commonContinue;

  /// No description provided for @commonDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get commonSave;

  /// No description provided for @commonApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get commonApply;

  /// No description provided for @commonClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get commonClose;

  /// No description provided for @commonCopy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get commonCopied;

  /// No description provided for @commonOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get commonOpen;

  /// No description provided for @commonRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get commonRetry;

  /// No description provided for @commonEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get commonEdit;

  /// No description provided for @commonSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get commonSend;

  /// No description provided for @commonOk.
  ///
  /// In ru, this message translates to:
  /// **'Ок'**
  String get commonOk;

  /// No description provided for @commonNext.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get commonNext;

  /// No description provided for @commonError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get commonError;

  /// No description provided for @commonErrorWith.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {message}'**
  String commonErrorWith(String message);

  /// No description provided for @commonSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get commonSearch;

  /// No description provided for @commonClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get commonClear;

  /// No description provided for @commonReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get commonReset;

  /// No description provided for @commonNothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get commonNothingFound;

  /// No description provided for @sessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Войдите снова.'**
  String get sessionExpired;

  /// No description provided for @sessionExpiredLogin.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get sessionExpiredLogin;

  /// No description provided for @connectionErrorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get connectionErrorTitle;

  /// No description provided for @connectionErrorRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get connectionErrorRetry;

  /// No description provided for @connectionErrorLoginAgain.
  ///
  /// In ru, this message translates to:
  /// **'Войти заново'**
  String get connectionErrorLoginAgain;

  /// No description provided for @connectionErrorOffline.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сервером. Проверьте интернет.'**
  String get connectionErrorOffline;

  /// No description provided for @connectionErrorServer.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не отвечает. Попробуйте позже.'**
  String get connectionErrorServer;

  /// No description provided for @connectionErrorTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Превышено время ожидания. Попробуйте ещё раз.'**
  String get connectionErrorTimeout;

  /// No description provided for @connectionErrorUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Произошла ошибка.'**
  String get connectionErrorUnknown;

  /// No description provided for @connectionErrorDetails.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее'**
  String get connectionErrorDetails;

  /// No description provided for @offlineBannerMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сервером — показаны последние данные'**
  String get offlineBannerMessage;

  /// No description provided for @offlineBannerRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get offlineBannerRetry;

  /// No description provided for @offlineBannerDismiss.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть'**
  String get offlineBannerDismiss;

  /// No description provided for @authBadCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Введите логин и пароль'**
  String get authBadCredentials;

  /// No description provided for @authConnectionTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Тайм-аут соединения с сервером — проблема со связью или сервера на тех работах'**
  String get authConnectionTimeout;

  /// No description provided for @authNetworkError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сети'**
  String get authNetworkError;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get loginTitle;

  /// No description provided for @loginLabel.
  ///
  /// In ru, this message translates to:
  /// **'Логин'**
  String get loginLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get passwordLabel;

  /// No description provided for @loginSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get loginSubmit;

  /// No description provided for @loginContinueAsGuest.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить как гость'**
  String get loginContinueAsGuest;

  /// No description provided for @loginRegisterHint.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта? Зарегистрироваться как студент'**
  String get loginRegisterHint;

  /// No description provided for @registerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get registerTitle;

  /// No description provided for @registerLoginEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите логин'**
  String get registerLoginEmpty;

  /// No description provided for @registerPasswordTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Пароль должен быть не короче 6 символов'**
  String get registerPasswordTooShort;

  /// No description provided for @registerPasswordsMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get registerPasswordsMismatch;

  /// No description provided for @registerGroupRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите группу'**
  String get registerGroupRequired;

  /// No description provided for @registerRepeatPassword.
  ///
  /// In ru, this message translates to:
  /// **'Повторите пароль'**
  String get registerRepeatPassword;

  /// No description provided for @registerSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get registerSubmit;

  /// No description provided for @registerHaveAccount.
  ///
  /// In ru, this message translates to:
  /// **'Есть аккаунт? Войти'**
  String get registerHaveAccount;

  /// No description provided for @registerGroupLabel.
  ///
  /// In ru, this message translates to:
  /// **'Группа'**
  String get registerGroupLabel;

  /// No description provided for @registerGroupsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить группы: {message}'**
  String registerGroupsLoadError(String message);

  /// No description provided for @newsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новости'**
  String get newsTitle;

  /// No description provided for @newsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет новостей'**
  String get newsEmpty;

  /// No description provided for @newsOpenInBrowser.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в браузере'**
  String get newsOpenInBrowser;

  /// No description provided for @newsOpenOnSource.
  ///
  /// In ru, this message translates to:
  /// **'Открыть на ncti.ru'**
  String get newsOpenOnSource;

  /// No description provided for @newsOfflineUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Статья ещё не подготовлена к офлайн-просмотру.'**
  String get newsOfflineUnavailable;

  /// No description provided for @notificationsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notificationsTitle;

  /// No description provided for @notificationsMarkAllReadTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Прочитать все'**
  String get notificationsMarkAllReadTooltip;

  /// No description provided for @notificationsSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get notificationsSend;

  /// No description provided for @notificationsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет уведомлений'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMarkAllConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Прочитать все?'**
  String get notificationsMarkAllConfirmTitle;

  /// No description provided for @notificationsMarkAllConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Пометить все уведомления как прочитанные?'**
  String get notificationsMarkAllConfirmBody;

  /// No description provided for @notificationsMarkAllConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Прочитать'**
  String get notificationsMarkAllConfirm;

  /// No description provided for @notificationsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить уведомления:\n{message}'**
  String notificationsLoadError(String message);

  /// No description provided for @notificationsScopeGlobal.
  ///
  /// In ru, this message translates to:
  /// **'ГЛОБАЛ'**
  String get notificationsScopeGlobal;

  /// No description provided for @notificationsSent.
  ///
  /// In ru, this message translates to:
  /// **'Отправлено'**
  String get notificationsSent;

  /// No description provided for @notificationsComposeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новое уведомление'**
  String get notificationsComposeTitle;

  /// No description provided for @notificationsRecipients.
  ///
  /// In ru, this message translates to:
  /// **'Кому'**
  String get notificationsRecipients;

  /// No description provided for @notificationsGlobal.
  ///
  /// In ru, this message translates to:
  /// **'Глобально'**
  String get notificationsGlobal;

  /// No description provided for @notificationsByGroup.
  ///
  /// In ru, this message translates to:
  /// **'По группам'**
  String get notificationsByGroup;

  /// No description provided for @notificationsGroups.
  ///
  /// In ru, this message translates to:
  /// **'Группы'**
  String get notificationsGroups;

  /// No description provided for @notificationsGroupSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск группы'**
  String get notificationsGroupSearch;

  /// No description provided for @notificationsGroupsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить группы'**
  String get notificationsGroupsLoadError;

  /// No description provided for @notificationsMessage.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение'**
  String get notificationsMessage;

  /// No description provided for @notificationsMessageHint.
  ///
  /// In ru, this message translates to:
  /// **'Что сообщить…'**
  String get notificationsMessageHint;

  /// No description provided for @notificationsLinkDate.
  ///
  /// In ru, this message translates to:
  /// **'Привязать к дате (необязательно)'**
  String get notificationsLinkDate;

  /// No description provided for @notificationsPickDate.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать дату'**
  String get notificationsPickDate;

  /// No description provided for @notificationsLinkedDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата: {date}'**
  String notificationsLinkedDate(String date);

  /// No description provided for @notificationsLinkedDateHint.
  ///
  /// In ru, this message translates to:
  /// **'Заметка появится у получателей в календаре на этот день.'**
  String get notificationsLinkedDateHint;

  /// No description provided for @notificationsServerError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сервера'**
  String get notificationsServerError;

  /// No description provided for @notificationsRelJustNow.
  ///
  /// In ru, this message translates to:
  /// **'только что'**
  String get notificationsRelJustNow;

  /// No description provided for @notificationsRelMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{count} мин назад'**
  String notificationsRelMinutes(int count);

  /// No description provided for @notificationsRelHours.
  ///
  /// In ru, this message translates to:
  /// **'{count} ч назад'**
  String notificationsRelHours(int count);

  /// No description provided for @notificationsRelDays.
  ///
  /// In ru, this message translates to:
  /// **'{count} дн назад'**
  String notificationsRelDays(int count);

  /// No description provided for @notifPrefsScheduleChanges.
  ///
  /// In ru, this message translates to:
  /// **'Изменения в расписании'**
  String get notifPrefsScheduleChanges;

  /// No description provided for @notifPrefsNews.
  ///
  /// In ru, this message translates to:
  /// **'Новости'**
  String get notifPrefsNews;

  /// No description provided for @notifPrefsMessages.
  ///
  /// In ru, this message translates to:
  /// **'Сообщения'**
  String get notifPrefsMessages;

  /// No description provided for @notifPrefsMinigameCalls.
  ///
  /// In ru, this message translates to:
  /// **'Вызовы в минииграх'**
  String get notifPrefsMinigameCalls;

  /// No description provided for @changePasswordTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена пароля'**
  String get changePasswordTitle;

  /// No description provided for @roleAdmin.
  ///
  /// In ru, this message translates to:
  /// **'админ'**
  String get roleAdmin;

  /// No description provided for @roleTeacher.
  ///
  /// In ru, this message translates to:
  /// **'преподаватель'**
  String get roleTeacher;

  /// No description provided for @roleStudent.
  ///
  /// In ru, this message translates to:
  /// **'студент'**
  String get roleStudent;

  /// No description provided for @roleSystem.
  ///
  /// In ru, this message translates to:
  /// **'система'**
  String get roleSystem;

  /// No description provided for @roleChipAdmin.
  ///
  /// In ru, this message translates to:
  /// **'АДМИН'**
  String get roleChipAdmin;

  /// No description provided for @roleChipTeacher.
  ///
  /// In ru, this message translates to:
  /// **'ПРЕПОД.'**
  String get roleChipTeacher;

  /// No description provided for @roleChipStudent.
  ///
  /// In ru, this message translates to:
  /// **'СТУДЕНТ'**
  String get roleChipStudent;

  /// No description provided for @roleChipSystem.
  ///
  /// In ru, this message translates to:
  /// **'СИСТЕМА'**
  String get roleChipSystem;

  /// No description provided for @notificationsAdminShowAllOn.
  ///
  /// In ru, this message translates to:
  /// **'Показаны все уведомления (включая групповые). Нажмите, чтобы скрыть групповые.'**
  String get notificationsAdminShowAllOn;

  /// No description provided for @notificationsAdminShowAllOff.
  ///
  /// In ru, this message translates to:
  /// **'Показаны только глобальные. Нажмите, чтобы включить групповые.'**
  String get notificationsAdminShowAllOff;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get settingsAccount;

  /// No description provided for @settingsNotLoggedIn.
  ///
  /// In ru, this message translates to:
  /// **'Вы не вошли'**
  String get settingsNotLoggedIn;

  /// No description provided for @settingsLoginToSync.
  ///
  /// In ru, this message translates to:
  /// **'Войдите, чтобы синхронизировать заметки'**
  String get settingsLoginToSync;

  /// No description provided for @settingsLogin.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get settingsLogin;

  /// No description provided for @settingsLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get settingsLogout;

  /// No description provided for @settingsChangePassword.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пароль'**
  String get settingsChangePassword;

  /// No description provided for @settingsPushTitle.
  ///
  /// In ru, this message translates to:
  /// **'Push-уведомления'**
  String get settingsPushTitle;

  /// No description provided for @settingsPrefNews.
  ///
  /// In ru, this message translates to:
  /// **'Новости'**
  String get settingsPrefNews;

  /// No description provided for @settingsPrefAnnouncements.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления от преподавателей и администрации'**
  String get settingsPrefAnnouncements;

  /// No description provided for @settingsPrefScheduleChanges.
  ///
  /// In ru, this message translates to:
  /// **'Изменения в расписании'**
  String get settingsPrefScheduleChanges;

  /// No description provided for @settingsPrefTokenPending.
  ///
  /// In ru, this message translates to:
  /// **'Ждём регистрации устройства…'**
  String get settingsPrefTokenPending;

  /// No description provided for @settingsInterface.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс'**
  String get settingsInterface;

  /// No description provided for @settingsHideEmptySlots.
  ///
  /// In ru, this message translates to:
  /// **'Скрывать пустые пары'**
  String get settingsHideEmptySlots;

  /// No description provided for @settingsShowLessonProgress.
  ///
  /// In ru, this message translates to:
  /// **'Прогресс текущей пары'**
  String get settingsShowLessonProgress;

  /// No description provided for @settingsShowWeekCarousel.
  ///
  /// In ru, this message translates to:
  /// **'Лента дней вместо сетки'**
  String get settingsShowWeekCarousel;

  /// No description provided for @settingsScheduleView.
  ///
  /// In ru, this message translates to:
  /// **'Вид расписания'**
  String get settingsScheduleView;

  /// No description provided for @settingsScheduleViewGrid.
  ///
  /// In ru, this message translates to:
  /// **'Сетка'**
  String get settingsScheduleViewGrid;

  /// No description provided for @settingsScheduleViewDayStrip.
  ///
  /// In ru, this message translates to:
  /// **'Лента дней'**
  String get settingsScheduleViewDayStrip;

  /// No description provided for @settingsScheduleViewWeekList.
  ///
  /// In ru, this message translates to:
  /// **'По неделям'**
  String get settingsScheduleViewWeekList;

  /// No description provided for @settingsDayColoring.
  ///
  /// In ru, this message translates to:
  /// **'Раскраска дней с парами'**
  String get settingsDayColoring;

  /// No description provided for @settingsDayColoringAuto.
  ///
  /// In ru, this message translates to:
  /// **'Авто'**
  String get settingsDayColoringAuto;

  /// No description provided for @settingsDayColoringHasLessons.
  ///
  /// In ru, this message translates to:
  /// **'Монотон'**
  String get settingsDayColoringHasLessons;

  /// No description provided for @settingsDayColoringEvenOdd.
  ///
  /// In ru, this message translates to:
  /// **'Чёт. / Нечёт.'**
  String get settingsDayColoringEvenOdd;

  /// No description provided for @settingsDynamicColor.
  ///
  /// In ru, this message translates to:
  /// **'Цвета системы'**
  String get settingsDynamicColor;

  /// No description provided for @settingsDynamicColorHint.
  ///
  /// In ru, this message translates to:
  /// **'Material You (Android 12+)'**
  String get settingsDynamicColorHint;

  /// No description provided for @settingsThemeSeedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Цвет темы'**
  String get settingsThemeSeedTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get settingsLanguageRu;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version} (сборка {build})'**
  String settingsVersion(String version, String build);

  /// No description provided for @settingsVersionLoading.
  ///
  /// In ru, this message translates to:
  /// **'Версия …'**
  String get settingsVersionLoading;

  /// No description provided for @settingsClearCache.
  ///
  /// In ru, this message translates to:
  /// **'Очистить кеш'**
  String get settingsClearCache;

  /// No description provided for @settingsClearCacheHint.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить локальный кеш расписания и фильтр. Авторизация сохранится.'**
  String get settingsClearCacheHint;

  /// No description provided for @settingsClearCacheConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очистить кеш?'**
  String get settingsClearCacheConfirmTitle;

  /// No description provided for @settingsClearCacheConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Локальный кеш расписания и сохранённый фильтр будут удалены. Авторизация сохранится.'**
  String get settingsClearCacheConfirmBody;

  /// No description provided for @settingsClearCacheDone.
  ///
  /// In ru, this message translates to:
  /// **'Кеш очищен. Перезапустите приложение.'**
  String get settingsClearCacheDone;

  /// No description provided for @settingsAccentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Цвет моих уведомлений'**
  String get settingsAccentTitle;

  /// No description provided for @settingsAccentHint.
  ///
  /// In ru, this message translates to:
  /// **'Отмечает ваши уведомления и прикреплённые заметки.'**
  String get settingsAccentHint;

  /// No description provided for @settingsAccentPick.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать цвет…'**
  String get settingsAccentPick;

  /// No description provided for @settingsAccentDefault.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию'**
  String get settingsAccentDefault;

  /// No description provided for @settingsChangePasswordTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пароль'**
  String get settingsChangePasswordTitle;

  /// No description provided for @settingsChangePasswordHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите текущий пароль и новый (>=6 символов, совпадают)'**
  String get settingsChangePasswordHint;

  /// No description provided for @settingsChangePasswordCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль'**
  String get settingsChangePasswordCurrent;

  /// No description provided for @settingsChangePasswordNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get settingsChangePasswordNew;

  /// No description provided for @settingsChangePasswordRepeat.
  ///
  /// In ru, this message translates to:
  /// **'Повторите новый пароль'**
  String get settingsChangePasswordRepeat;

  /// No description provided for @settingsChangePasswordSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Сменить'**
  String get settingsChangePasswordSubmit;

  /// No description provided for @settingsChangePasswordDone.
  ///
  /// In ru, this message translates to:
  /// **'Пароль изменён'**
  String get settingsChangePasswordDone;

  /// No description provided for @settingsDebugTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отладка'**
  String get settingsDebugTitle;

  /// No description provided for @settingsDebugTestTime.
  ///
  /// In ru, this message translates to:
  /// **'Тестовое время'**
  String get settingsDebugTestTime;

  /// No description provided for @settingsDebugConnState.
  ///
  /// In ru, this message translates to:
  /// **'Состояние соединения'**
  String get settingsDebugConnState;

  /// No description provided for @settingsDebugOnline.
  ///
  /// In ru, this message translates to:
  /// **'онлайн'**
  String get settingsDebugOnline;

  /// No description provided for @settingsDebugOffline.
  ///
  /// In ru, this message translates to:
  /// **'оффлайн'**
  String get settingsDebugOffline;

  /// No description provided for @settingsDebugNoteQueue.
  ///
  /// In ru, this message translates to:
  /// **'Очередь заметок'**
  String get settingsDebugNoteQueue;

  /// No description provided for @settingsDebugQueueEmpty.
  ///
  /// In ru, this message translates to:
  /// **'пусто'**
  String get settingsDebugQueueEmpty;

  /// No description provided for @settingsDebugQueueOps.
  ///
  /// In ru, this message translates to:
  /// **'{count} оп.'**
  String settingsDebugQueueOps(int count);

  /// No description provided for @settingsDebugLastSync.
  ///
  /// In ru, this message translates to:
  /// **'Последняя синхронизация'**
  String get settingsDebugLastSync;

  /// No description provided for @settingsDebugShowFcm.
  ///
  /// In ru, this message translates to:
  /// **'Показать FCM токен'**
  String get settingsDebugShowFcm;

  /// No description provided for @settingsDebugForceSync.
  ///
  /// In ru, this message translates to:
  /// **'Принудительная синхронизация'**
  String get settingsDebugForceSync;

  /// No description provided for @settingsDebugClearStorage.
  ///
  /// In ru, this message translates to:
  /// **'Очистить локальное хранилище'**
  String get settingsDebugClearStorage;

  /// No description provided for @settingsDebugDatePickHelp.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get settingsDebugDatePickHelp;

  /// No description provided for @settingsDebugTimePickHelp.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get settingsDebugTimePickHelp;

  /// No description provided for @settingsDebugFcmTitle.
  ///
  /// In ru, this message translates to:
  /// **'FCM токен'**
  String get settingsDebugFcmTitle;

  /// No description provided for @settingsDebugFcmUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'(токен недоступен)'**
  String get settingsDebugFcmUnavailable;

  /// No description provided for @settingsDebugFcmError.
  ///
  /// In ru, this message translates to:
  /// **'(ошибка: {message})'**
  String settingsDebugFcmError(String message);

  /// No description provided for @settingsDebugQueueEmptyMsg.
  ///
  /// In ru, this message translates to:
  /// **'Очередь пуста'**
  String get settingsDebugQueueEmptyMsg;

  /// No description provided for @settingsDebugQueueNotSent.
  ///
  /// In ru, this message translates to:
  /// **'Не отправлено: {count}'**
  String settingsDebugQueueNotSent(int count);

  /// No description provided for @settingsDebugClearConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очистить хранилище?'**
  String get settingsDebugClearConfirmTitle;

  /// No description provided for @settingsDebugClearConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Будут удалены локальные настройки, очередь заметок, кэш и тема. Авторизация сохранится.'**
  String get settingsDebugClearConfirmBody;

  /// No description provided for @settingsDebugClearDone.
  ///
  /// In ru, this message translates to:
  /// **'Хранилище очищено. Перезапустите приложение.'**
  String get settingsDebugClearDone;

  /// No description provided for @settingsDebugWidgetLog.
  ///
  /// In ru, this message translates to:
  /// **'Лог виджета'**
  String get settingsDebugWidgetLog;

  /// No description provided for @settingsDebugWidgetLogEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Лог пуст или файл не существует.'**
  String get settingsDebugWidgetLogEmpty;

  /// No description provided for @settingsDebugWidgetLogUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Внешнее хранилище недоступно.'**
  String get settingsDebugWidgetLogUnavailable;

  /// No description provided for @settingsDebugPalette.
  ///
  /// In ru, this message translates to:
  /// **'Палитра (отладка)'**
  String get settingsDebugPalette;

  /// No description provided for @paletteDebugTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отладка палитры'**
  String get paletteDebugTitle;

  /// No description provided for @paletteDebugHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на образец, чтобы временно переопределить токен. Изменения применяются вживую.'**
  String get paletteDebugHint;

  /// No description provided for @paletteDebugReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get paletteDebugReset;

  /// No description provided for @paletteDebugResetDone.
  ///
  /// In ru, this message translates to:
  /// **'Все переопределения сброшены'**
  String get paletteDebugResetDone;

  /// No description provided for @paletteDebugSeedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Основной цвет'**
  String get paletteDebugSeedLabel;

  /// No description provided for @paletteDebugInspectorLabel.
  ///
  /// In ru, this message translates to:
  /// **'Инспектор регионов'**
  String get paletteDebugInspectorLabel;

  /// No description provided for @paletteDebugClearOverrideTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить переопределение'**
  String get paletteDebugClearOverrideTooltip;

  /// No description provided for @colorPickerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите цвет'**
  String get colorPickerTitle;

  /// No description provided for @colorPickerPrimary.
  ///
  /// In ru, this message translates to:
  /// **'Основные'**
  String get colorPickerPrimary;

  /// No description provided for @colorPickerWheel.
  ///
  /// In ru, this message translates to:
  /// **'Колесо'**
  String get colorPickerWheel;

  /// No description provided for @colorPickerPrimaryHeading.
  ///
  /// In ru, this message translates to:
  /// **'Основные цвета'**
  String get colorPickerPrimaryHeading;

  /// No description provided for @colorPickerShade.
  ///
  /// In ru, this message translates to:
  /// **'Оттенок'**
  String get colorPickerShade;

  /// No description provided for @colorPickerCustom.
  ///
  /// In ru, this message translates to:
  /// **'Произвольный цвет'**
  String get colorPickerCustom;

  /// No description provided for @colorPickerCopied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано в буфер обмена'**
  String get colorPickerCopied;

  /// No description provided for @pushRationaleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get pushRationaleTitle;

  /// No description provided for @pushRationaleBodyWeb.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите уведомления, чтобы получать сообщения от преподавателей и узнавать об изменениях в расписании.\n\nПосле нажатия «Разрешить» браузер покажет системный запрос.'**
  String get pushRationaleBodyWeb;

  /// No description provided for @pushRationaleBodyMobile.
  ///
  /// In ru, this message translates to:
  /// **'Включите уведомления, чтобы получать сообщения от преподавателей и узнавать об изменениях в расписании.'**
  String get pushRationaleBodyMobile;

  /// No description provided for @pushRationaleLater.
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get pushRationaleLater;

  /// No description provided for @pushRationaleNotNow.
  ///
  /// In ru, this message translates to:
  /// **'Не сейчас'**
  String get pushRationaleNotNow;

  /// No description provided for @pushRationaleAllow.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить'**
  String get pushRationaleAllow;

  /// No description provided for @pushSnackbarOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть'**
  String get pushSnackbarOpen;

  /// No description provided for @pushPermissionBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления заблокированы в браузере'**
  String get pushPermissionBlocked;

  /// No description provided for @pushPermissionBlockedMobile.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления заблокированы в настройках системы'**
  String get pushPermissionBlockedMobile;

  /// No description provided for @pushPermissionBlockedHelpTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как разблокировать'**
  String get pushPermissionBlockedHelpTitle;

  /// No description provided for @pushPermissionBlockedHelpBodyWeb.
  ///
  /// In ru, this message translates to:
  /// **'Откройте настройки сайта в браузере (обычно значок замка в адресной строке), разрешите уведомления для этого сайта и перезагрузите страницу.'**
  String get pushPermissionBlockedHelpBodyWeb;

  /// No description provided for @pushPermissionBlockedHelpBodyMobile.
  ///
  /// In ru, this message translates to:
  /// **'Откройте системные настройки приложения и разрешите уведомления, затем вернитесь.'**
  String get pushPermissionBlockedHelpBodyMobile;

  /// No description provided for @pushPermissionDeniedSnack.
  ///
  /// In ru, this message translates to:
  /// **'Разрешение не получено'**
  String get pushPermissionDeniedSnack;

  /// No description provided for @pushPermissionBlockedHelpOk.
  ///
  /// In ru, this message translates to:
  /// **'Понятно'**
  String get pushPermissionBlockedHelpOk;

  /// No description provided for @noteQueueSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить заметку: {message}'**
  String noteQueueSaveError(String message);

  /// No description provided for @timeMinutesShort.
  ///
  /// In ru, this message translates to:
  /// **'{count} мин'**
  String timeMinutesShort(int count);

  /// No description provided for @timeHours.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} час} few{{count} часа} other{{count} часов}}'**
  String timeHours(int count);

  /// No description provided for @timeHoursMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{hours, plural, one{{hours} час} few{{hours} часа} other{{hours} часов}} {minutes} мин'**
  String timeHoursMinutes(int hours, int minutes);

  /// No description provided for @scheduleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Расписание'**
  String get scheduleTitle;

  /// No description provided for @scheduleReturnToToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get scheduleReturnToToday;

  /// No description provided for @scheduleFilterGroup.
  ///
  /// In ru, this message translates to:
  /// **'Группа'**
  String get scheduleFilterGroup;

  /// No description provided for @scheduleFilterTeacher.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель'**
  String get scheduleFilterTeacher;

  /// No description provided for @scheduleFilterRoom.
  ///
  /// In ru, this message translates to:
  /// **'Кабинет'**
  String get scheduleFilterRoom;

  /// No description provided for @scheduleFilterGroupPick.
  ///
  /// In ru, this message translates to:
  /// **'Выберите группу'**
  String get scheduleFilterGroupPick;

  /// No description provided for @scheduleFilterTeacherPick.
  ///
  /// In ru, this message translates to:
  /// **'Выберите преподавателя'**
  String get scheduleFilterTeacherPick;

  /// No description provided for @scheduleFilterRoomPick.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кабинет'**
  String get scheduleFilterRoomPick;

  /// No description provided for @scheduleHasLessons.
  ///
  /// In ru, this message translates to:
  /// **'Есть занятия'**
  String get scheduleHasLessons;

  /// No description provided for @scheduleNoLessons.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий'**
  String get scheduleNoLessons;

  /// No description provided for @scheduleWeekOdd.
  ///
  /// In ru, this message translates to:
  /// **'Нечётная неделя'**
  String get scheduleWeekOdd;

  /// No description provided for @scheduleWeekEven.
  ///
  /// In ru, this message translates to:
  /// **'Чётная неделя'**
  String get scheduleWeekEven;

  /// No description provided for @scheduleNoFilterPicked.
  ///
  /// In ru, this message translates to:
  /// **'Выберите группу, преподавателя или кабинет'**
  String get scheduleNoFilterPicked;

  /// No description provided for @scheduleNoLessonsOnDay.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий на этот день'**
  String get scheduleNoLessonsOnDay;

  /// No description provided for @scheduleNoLessonsOnDayShort.
  ///
  /// In ru, this message translates to:
  /// **'Нет занятий'**
  String get scheduleNoLessonsOnDayShort;

  /// No description provided for @scheduleNoDataForWeek.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных за эту неделю'**
  String get scheduleNoDataForWeek;

  /// No description provided for @scheduleTodayBadge.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get scheduleTodayBadge;

  /// No description provided for @scheduleWeekPrev.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущая'**
  String get scheduleWeekPrev;

  /// No description provided for @scheduleWeekCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущая'**
  String get scheduleWeekCurrent;

  /// No description provided for @scheduleWeekNext.
  ///
  /// In ru, this message translates to:
  /// **'Следующая'**
  String get scheduleWeekNext;

  /// No description provided for @scheduleWeekRange.
  ///
  /// In ru, this message translates to:
  /// **'{fromDay}–{toDay} {month}'**
  String scheduleWeekRange(int fromDay, int toDay, String month);

  /// No description provided for @scheduleWeekRangeCrossMonth.
  ///
  /// In ru, this message translates to:
  /// **'{fromDay} {fromMonth} – {toDay} {toMonth}'**
  String scheduleWeekRangeCrossMonth(
      int fromDay, String fromMonth, int toDay, String toMonth);

  /// No description provided for @weekListRangeSameMonth.
  ///
  /// In ru, this message translates to:
  /// **'{fromDay} {month} – {toDay} {month}, {parity}'**
  String weekListRangeSameMonth(
      int fromDay, int toDay, String month, String parity);

  /// No description provided for @weekListRangeCrossMonth.
  ///
  /// In ru, this message translates to:
  /// **'{fromDay} {fromMonth} – {toDay} {toMonth}, {parity}'**
  String weekListRangeCrossMonth(
      int fromDay, String fromMonth, int toDay, String toMonth, String parity);

  /// No description provided for @weekListRangeCrossYear.
  ///
  /// In ru, this message translates to:
  /// **'{fromDay} {fromMonth} {fromYear} – {toDay} {toMonth} {toYear}, {parity}'**
  String weekListRangeCrossYear(int fromDay, String fromMonth, int fromYear,
      int toDay, String toMonth, int toYear, String parity);

  /// No description provided for @weekListParityEven.
  ///
  /// In ru, this message translates to:
  /// **'чётная'**
  String get weekListParityEven;

  /// No description provided for @weekListParityOdd.
  ///
  /// In ru, this message translates to:
  /// **'нечётная'**
  String get weekListParityOdd;

  /// No description provided for @scheduleDayHeader.
  ///
  /// In ru, this message translates to:
  /// **'{day} {month} {year}, {weekday}'**
  String scheduleDayHeader(int day, String month, int year, String weekday);

  /// No description provided for @scheduleNowOngoing.
  ///
  /// In ru, this message translates to:
  /// **'Идёт сейчас'**
  String get scheduleNowOngoing;

  /// No description provided for @scheduleNowEndsInMin.
  ///
  /// In ru, this message translates to:
  /// **'Заканчивается через {count} мин'**
  String scheduleNowEndsInMin(int count);

  /// No description provided for @scheduleNowOngoingUntil.
  ///
  /// In ru, this message translates to:
  /// **'Идёт сейчас · до конца {timeLeft}'**
  String scheduleNowOngoingUntil(String timeLeft);

  /// No description provided for @scheduleStartsIn.
  ///
  /// In ru, this message translates to:
  /// **'Начнётся через {timeLeft}'**
  String scheduleStartsIn(String timeLeft);

  /// No description provided for @scheduleNow.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас'**
  String get scheduleNow;

  /// No description provided for @schedulePairOrdinal.
  ///
  /// In ru, this message translates to:
  /// **'Пара {ordinal}'**
  String schedulePairOrdinal(int ordinal);

  /// No description provided for @scheduleOrdinalPair.
  ///
  /// In ru, this message translates to:
  /// **'{ordinal} пара'**
  String scheduleOrdinalPair(int ordinal);

  /// No description provided for @scheduleSubgroup.
  ///
  /// In ru, this message translates to:
  /// **'подгруппа {value}'**
  String scheduleSubgroup(String value);

  /// No description provided for @scheduleOverrideIndicator.
  ///
  /// In ru, this message translates to:
  /// **'Изменено'**
  String get scheduleOverrideIndicator;

  /// No description provided for @scheduleNoteLabel.
  ///
  /// In ru, this message translates to:
  /// **'Заметка'**
  String get scheduleNoteLabel;

  /// No description provided for @scheduleNoteOfflineHint.
  ///
  /// In ru, this message translates to:
  /// **'Заметка будет сохранена при подключении к интернету'**
  String get scheduleNoteOfflineHint;

  /// No description provided for @schedulePinnedNoteSingle.
  ///
  /// In ru, this message translates to:
  /// **'Закреплённая заметка'**
  String get schedulePinnedNoteSingle;

  /// No description provided for @schedulePinnedNoteMany.
  ///
  /// In ru, this message translates to:
  /// **'Закреплённые заметки'**
  String get schedulePinnedNoteMany;

  /// No description provided for @scheduleDeleteNoteConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить заметку?'**
  String get scheduleDeleteNoteConfirmTitle;

  /// No description provided for @scheduleDeleteNoteConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Закреплённая заметка будет удалена у всех получателей.'**
  String get scheduleDeleteNoteConfirmBody;

  /// No description provided for @scheduleRelToday.
  ///
  /// In ru, this message translates to:
  /// **'сегодня в {time}'**
  String scheduleRelToday(String time);

  /// No description provided for @scheduleRelYesterday.
  ///
  /// In ru, this message translates to:
  /// **'вчера в {time}'**
  String scheduleRelYesterday(String time);

  /// No description provided for @scheduleRelDaysAgo.
  ///
  /// In ru, this message translates to:
  /// **'{count} дн назад'**
  String scheduleRelDaysAgo(int count);

  /// No description provided for @scheduleNoteTime.
  ///
  /// In ru, this message translates to:
  /// **'Время: {day} {month}, {time}'**
  String scheduleNoteTime(int day, String month, String time);

  /// No description provided for @scheduleOfflineBanner.
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения. Работаем из кэша.'**
  String get scheduleOfflineBanner;

  /// No description provided for @scheduleNoteForDay.
  ///
  /// In ru, this message translates to:
  /// **'Заметка на {day}'**
  String scheduleNoteForDay(String day);

  /// No description provided for @scheduleNoteHint.
  ///
  /// In ru, this message translates to:
  /// **'Что-то важное на этот день…'**
  String get scheduleNoteHint;

  /// No description provided for @scheduleLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить расписание:\n{message}'**
  String scheduleLoadError(String message);

  /// No description provided for @scheduleNoConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сервером'**
  String get scheduleNoConnection;

  /// No description provided for @monthShortJan.
  ///
  /// In ru, this message translates to:
  /// **'янв'**
  String get monthShortJan;

  /// No description provided for @monthShortFeb.
  ///
  /// In ru, this message translates to:
  /// **'фев'**
  String get monthShortFeb;

  /// No description provided for @monthShortMar.
  ///
  /// In ru, this message translates to:
  /// **'мар'**
  String get monthShortMar;

  /// No description provided for @monthShortApr.
  ///
  /// In ru, this message translates to:
  /// **'апр'**
  String get monthShortApr;

  /// No description provided for @monthShortMay.
  ///
  /// In ru, this message translates to:
  /// **'май'**
  String get monthShortMay;

  /// No description provided for @monthShortJun.
  ///
  /// In ru, this message translates to:
  /// **'июн'**
  String get monthShortJun;

  /// No description provided for @monthShortJul.
  ///
  /// In ru, this message translates to:
  /// **'июл'**
  String get monthShortJul;

  /// No description provided for @monthShortAug.
  ///
  /// In ru, this message translates to:
  /// **'авг'**
  String get monthShortAug;

  /// No description provided for @monthShortSep.
  ///
  /// In ru, this message translates to:
  /// **'сен'**
  String get monthShortSep;

  /// No description provided for @monthShortOct.
  ///
  /// In ru, this message translates to:
  /// **'окт'**
  String get monthShortOct;

  /// No description provided for @monthShortNov.
  ///
  /// In ru, this message translates to:
  /// **'ноя'**
  String get monthShortNov;

  /// No description provided for @monthShortDec.
  ///
  /// In ru, this message translates to:
  /// **'дек'**
  String get monthShortDec;

  /// No description provided for @monthGenJan.
  ///
  /// In ru, this message translates to:
  /// **'января'**
  String get monthGenJan;

  /// No description provided for @monthGenFeb.
  ///
  /// In ru, this message translates to:
  /// **'февраля'**
  String get monthGenFeb;

  /// No description provided for @monthGenMar.
  ///
  /// In ru, this message translates to:
  /// **'марта'**
  String get monthGenMar;

  /// No description provided for @monthGenApr.
  ///
  /// In ru, this message translates to:
  /// **'апреля'**
  String get monthGenApr;

  /// No description provided for @monthGenMay.
  ///
  /// In ru, this message translates to:
  /// **'мая'**
  String get monthGenMay;

  /// No description provided for @monthGenJun.
  ///
  /// In ru, this message translates to:
  /// **'июня'**
  String get monthGenJun;

  /// No description provided for @monthGenJul.
  ///
  /// In ru, this message translates to:
  /// **'июля'**
  String get monthGenJul;

  /// No description provided for @monthGenAug.
  ///
  /// In ru, this message translates to:
  /// **'августа'**
  String get monthGenAug;

  /// No description provided for @monthGenSep.
  ///
  /// In ru, this message translates to:
  /// **'сентября'**
  String get monthGenSep;

  /// No description provided for @monthGenOct.
  ///
  /// In ru, this message translates to:
  /// **'октября'**
  String get monthGenOct;

  /// No description provided for @monthGenNov.
  ///
  /// In ru, this message translates to:
  /// **'ноября'**
  String get monthGenNov;

  /// No description provided for @monthGenDec.
  ///
  /// In ru, this message translates to:
  /// **'декабря'**
  String get monthGenDec;

  /// No description provided for @monthLongJan.
  ///
  /// In ru, this message translates to:
  /// **'Январь'**
  String get monthLongJan;

  /// No description provided for @monthLongFeb.
  ///
  /// In ru, this message translates to:
  /// **'Февраль'**
  String get monthLongFeb;

  /// No description provided for @monthLongMar.
  ///
  /// In ru, this message translates to:
  /// **'Март'**
  String get monthLongMar;

  /// No description provided for @monthLongApr.
  ///
  /// In ru, this message translates to:
  /// **'Апрель'**
  String get monthLongApr;

  /// No description provided for @monthLongMay.
  ///
  /// In ru, this message translates to:
  /// **'Май'**
  String get monthLongMay;

  /// No description provided for @monthLongJun.
  ///
  /// In ru, this message translates to:
  /// **'Июнь'**
  String get monthLongJun;

  /// No description provided for @monthLongJul.
  ///
  /// In ru, this message translates to:
  /// **'Июль'**
  String get monthLongJul;

  /// No description provided for @monthLongAug.
  ///
  /// In ru, this message translates to:
  /// **'Август'**
  String get monthLongAug;

  /// No description provided for @monthLongSep.
  ///
  /// In ru, this message translates to:
  /// **'Сентябрь'**
  String get monthLongSep;

  /// No description provided for @monthLongOct.
  ///
  /// In ru, this message translates to:
  /// **'Октябрь'**
  String get monthLongOct;

  /// No description provided for @monthLongNov.
  ///
  /// In ru, this message translates to:
  /// **'Ноябрь'**
  String get monthLongNov;

  /// No description provided for @monthLongDec.
  ///
  /// In ru, this message translates to:
  /// **'Декабрь'**
  String get monthLongDec;

  /// No description provided for @weekdayShortMon.
  ///
  /// In ru, this message translates to:
  /// **'Пн'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In ru, this message translates to:
  /// **'Вт'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In ru, this message translates to:
  /// **'Ср'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In ru, this message translates to:
  /// **'Чт'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In ru, this message translates to:
  /// **'Пт'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In ru, this message translates to:
  /// **'Сб'**
  String get weekdayShortSat;

  /// No description provided for @weekdayShortSun.
  ///
  /// In ru, this message translates to:
  /// **'Вс'**
  String get weekdayShortSun;

  /// No description provided for @weekdayLongMon.
  ///
  /// In ru, this message translates to:
  /// **'понедельник'**
  String get weekdayLongMon;

  /// No description provided for @weekdayLongTue.
  ///
  /// In ru, this message translates to:
  /// **'вторник'**
  String get weekdayLongTue;

  /// No description provided for @weekdayLongWed.
  ///
  /// In ru, this message translates to:
  /// **'среда'**
  String get weekdayLongWed;

  /// No description provided for @weekdayLongThu.
  ///
  /// In ru, this message translates to:
  /// **'четверг'**
  String get weekdayLongThu;

  /// No description provided for @weekdayLongFri.
  ///
  /// In ru, this message translates to:
  /// **'пятница'**
  String get weekdayLongFri;

  /// No description provided for @weekdayLongSat.
  ///
  /// In ru, this message translates to:
  /// **'суббота'**
  String get weekdayLongSat;

  /// No description provided for @weekdayLongSun.
  ///
  /// In ru, this message translates to:
  /// **'воскресенье'**
  String get weekdayLongSun;

  /// No description provided for @scheduleSelectedDate.
  ///
  /// In ru, this message translates to:
  /// **'{day} {month}, {weekday}'**
  String scheduleSelectedDate(int day, String month, String weekday);

  /// No description provided for @scheduleMonthHeader.
  ///
  /// In ru, this message translates to:
  /// **'{month} {year}'**
  String scheduleMonthHeader(String month, int year);

  /// No description provided for @adminTitle.
  ///
  /// In ru, this message translates to:
  /// **'Администрирование'**
  String get adminTitle;

  /// No description provided for @adminTabUsers.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get adminTabUsers;

  /// No description provided for @adminTabCreateTeacher.
  ///
  /// In ru, this message translates to:
  /// **'Создать препод.'**
  String get adminTabCreateTeacher;

  /// No description provided for @adminTabCreateAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Создать админа'**
  String get adminTabCreateAdmin;

  /// No description provided for @adminTabPushRights.
  ///
  /// In ru, this message translates to:
  /// **'Push-права'**
  String get adminTabPushRights;

  /// No description provided for @adminTabActivity.
  ///
  /// In ru, this message translates to:
  /// **'Активность'**
  String get adminTabActivity;

  /// No description provided for @adminTabSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get adminTabSettings;

  /// No description provided for @adminSearchLogin.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по логину'**
  String get adminSearchLogin;

  /// No description provided for @adminRoleAdmins.
  ///
  /// In ru, this message translates to:
  /// **'Админы'**
  String get adminRoleAdmins;

  /// No description provided for @adminRoleTeachers.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватели'**
  String get adminRoleTeachers;

  /// No description provided for @adminRoleStudents.
  ///
  /// In ru, this message translates to:
  /// **'Студенты'**
  String get adminRoleStudents;

  /// No description provided for @adminUsersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет пользователей'**
  String get adminUsersEmpty;

  /// No description provided for @adminRecordDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Запись удалена'**
  String get adminRecordDeleted;

  /// No description provided for @adminSelfMarker.
  ///
  /// In ru, this message translates to:
  /// **'вы'**
  String get adminSelfMarker;

  /// No description provided for @adminLastActive.
  ///
  /// In ru, this message translates to:
  /// **'активн.: {timestamp}'**
  String adminLastActive(String timestamp);

  /// No description provided for @adminActions.
  ///
  /// In ru, this message translates to:
  /// **'Действия'**
  String get adminActions;

  /// No description provided for @adminResetPassword.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить пароль'**
  String get adminResetPassword;

  /// No description provided for @adminGroupPrefix.
  ///
  /// In ru, this message translates to:
  /// **'группа {name}'**
  String adminGroupPrefix(String name);

  /// No description provided for @adminResetOwnConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить пароль себе?'**
  String get adminResetOwnConfirmTitle;

  /// No description provided for @adminResetOwnConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Вы сбрасываете пароль собственному аккаунту. После этого нужно будет войти заново. Продолжить?'**
  String get adminResetOwnConfirmBody;

  /// No description provided for @adminDeleteUserConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить пользователя?'**
  String get adminDeleteUserConfirmTitle;

  /// No description provided for @adminDeleteUserConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Удалить «{login}» ({role})?'**
  String adminDeleteUserConfirmBody(String login, String role);

  /// No description provided for @adminPasswordUpdatedFor.
  ///
  /// In ru, this message translates to:
  /// **'Пароль обновлён для {login}'**
  String adminPasswordUpdatedFor(String login);

  /// No description provided for @adminResetPasswordFor.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить пароль: {login}'**
  String adminResetPasswordFor(String login);

  /// No description provided for @adminNewPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get adminNewPassword;

  /// No description provided for @adminConfirmPassword.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите пароль'**
  String get adminConfirmPassword;

  /// No description provided for @adminCreateTeacherFormHint.
  ///
  /// In ru, this message translates to:
  /// **'Заполните логин, пароль (>=6) и выберите преподавателя'**
  String get adminCreateTeacherFormHint;

  /// No description provided for @adminCreatedNotice.
  ///
  /// In ru, this message translates to:
  /// **'Создано: {login}'**
  String adminCreatedNotice(String login);

  /// No description provided for @adminLoginField.
  ///
  /// In ru, this message translates to:
  /// **'Логин'**
  String get adminLoginField;

  /// No description provided for @adminPasswordField.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get adminPasswordField;

  /// No description provided for @adminLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки: {message}'**
  String adminLoadError(String message);

  /// No description provided for @adminTeacherField.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватель'**
  String get adminTeacherField;

  /// No description provided for @adminCreateTeacherTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создать преподавателя'**
  String get adminCreateTeacherTitle;

  /// No description provided for @adminCreateAdminTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создать администратора'**
  String get adminCreateAdminTitle;

  /// No description provided for @adminCreateAdminRequired.
  ///
  /// In ru, this message translates to:
  /// **'Логин и пароль (>=6) обязательны'**
  String get adminCreateAdminRequired;

  /// No description provided for @adminCreateAdminCreated.
  ///
  /// In ru, this message translates to:
  /// **'Администратор создан: {login}'**
  String adminCreateAdminCreated(String login);

  /// No description provided for @adminPushHint.
  ///
  /// In ru, this message translates to:
  /// **'Можно отключить возможность рассылки уведомлений для отдельного преподавателя.'**
  String get adminPushHint;

  /// No description provided for @adminNoTeachers.
  ///
  /// In ru, this message translates to:
  /// **'Нет пользователей-преподавателей'**
  String get adminNoTeachers;

  /// No description provided for @adminTeacherUnlinked.
  ///
  /// In ru, this message translates to:
  /// **'преподаватель не привязан'**
  String get adminTeacherUnlinked;

  /// No description provided for @adminTeacherId.
  ///
  /// In ru, this message translates to:
  /// **'препод. #{id}'**
  String adminTeacherId(String id);

  /// No description provided for @adminCanPushLabel.
  ///
  /// In ru, this message translates to:
  /// **'Может отправлять уведомления'**
  String get adminCanPushLabel;

  /// No description provided for @adminCanBroadcastGloballyLabel.
  ///
  /// In ru, this message translates to:
  /// **'Может отправлять всем'**
  String get adminCanBroadcastGloballyLabel;

  /// No description provided for @adminNotificationsTab.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get adminNotificationsTab;

  /// No description provided for @adminAppSettingsError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки: {message}'**
  String adminAppSettingsError(String message);

  /// No description provided for @adminTeachersGlobalTitle.
  ///
  /// In ru, this message translates to:
  /// **'Преподаватели могут отправлять глобальные уведомления'**
  String get adminTeachersGlobalTitle;

  /// No description provided for @adminTeachersGlobalHint.
  ///
  /// In ru, this message translates to:
  /// **'Если выключено, преподаватели рассылают только по группам'**
  String get adminTeachersGlobalHint;

  /// No description provided for @adminNewsScrapeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сбор новостей'**
  String get adminNewsScrapeTitle;

  /// No description provided for @adminNewsScrapeHint.
  ///
  /// In ru, this message translates to:
  /// **'Получить свежие новости с сайта колледжа прямо сейчас. Сбор также запускается автоматически по расписанию.'**
  String get adminNewsScrapeHint;

  /// No description provided for @adminNewsScrapeButton.
  ///
  /// In ru, this message translates to:
  /// **'Запустить сбор новостей'**
  String get adminNewsScrapeButton;

  /// No description provided for @adminNewsScrapeAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Сбор новостей запущен'**
  String get adminNewsScrapeAccepted;

  /// No description provided for @adminNewsScrapeBusy.
  ///
  /// In ru, this message translates to:
  /// **'Сбор уже идёт'**
  String get adminNewsScrapeBusy;

  /// No description provided for @adminNoData.
  ///
  /// In ru, this message translates to:
  /// **'данных нет'**
  String get adminNoData;

  /// No description provided for @adminStorageNotes.
  ///
  /// In ru, this message translates to:
  /// **'заметки {size}'**
  String adminStorageNotes(String size);

  /// No description provided for @adminStorageTotal.
  ///
  /// In ru, this message translates to:
  /// **'всего {size}'**
  String adminStorageTotal(String size);

  /// No description provided for @adminActivityEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Событий нет'**
  String get adminActivityEmpty;

  /// No description provided for @adminActivity7d.
  ///
  /// In ru, this message translates to:
  /// **'За 7 дней'**
  String get adminActivity7d;

  /// No description provided for @adminActivity30d.
  ///
  /// In ru, this message translates to:
  /// **'За 30 дней'**
  String get adminActivity30d;

  /// No description provided for @adminActivityRegistrations.
  ///
  /// In ru, this message translates to:
  /// **'Регистраций'**
  String get adminActivityRegistrations;

  /// No description provided for @adminActivityFailedLogins.
  ///
  /// In ru, this message translates to:
  /// **'Неудачных входов'**
  String get adminActivityFailedLogins;

  /// No description provided for @adminActivityPasswordResets.
  ///
  /// In ru, this message translates to:
  /// **'Сбросов паролей'**
  String get adminActivityPasswordResets;

  /// No description provided for @adminActivitySentNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Отправленных уведомлений'**
  String get adminActivitySentNotifications;

  /// No description provided for @activityLabelRegister.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get activityLabelRegister;

  /// No description provided for @activityLabelLogin.
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get activityLabelLogin;

  /// No description provided for @activityLabelLoginFailed.
  ///
  /// In ru, this message translates to:
  /// **'Неудачный вход'**
  String get activityLabelLoginFailed;

  /// No description provided for @activityLabelPasswordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Смена пароля'**
  String get activityLabelPasswordChanged;

  /// No description provided for @activityLabelPasswordResetByAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Сброс пароля (админ)'**
  String get activityLabelPasswordResetByAdmin;

  /// No description provided for @activityLabelCreatedByAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Создан админом'**
  String get activityLabelCreatedByAdmin;

  /// No description provided for @activityLabelUserDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Удалён'**
  String get activityLabelUserDeleted;

  /// No description provided for @activityLabelCanPushToggled.
  ///
  /// In ru, this message translates to:
  /// **'Push-права изменены'**
  String get activityLabelCanPushToggled;

  /// No description provided for @activityLabelCanBroadcastGloballyToggled.
  ///
  /// In ru, this message translates to:
  /// **'Права на глобальную рассылку изменены'**
  String get activityLabelCanBroadcastGloballyToggled;

  /// No description provided for @activityLabelAccentColorSet.
  ///
  /// In ru, this message translates to:
  /// **'Выбран акцентный цвет'**
  String get activityLabelAccentColorSet;

  /// No description provided for @activityLabelNotifPrefsSet.
  ///
  /// In ru, this message translates to:
  /// **'Настройки уведомлений изменены'**
  String get activityLabelNotifPrefsSet;

  /// No description provided for @activityLabelLoggedOut.
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get activityLabelLoggedOut;

  /// No description provided for @activityLabelAdminSettingUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Настройка администратора изменена'**
  String get activityLabelAdminSettingUpdated;

  /// No description provided for @activityLabelNewsScrapeTriggered.
  ///
  /// In ru, this message translates to:
  /// **'Запущен сбор новостей'**
  String get activityLabelNewsScrapeTriggered;

  /// No description provided for @activityLabelNotificationSent.
  ///
  /// In ru, this message translates to:
  /// **'Отправлено уведомление'**
  String get activityLabelNotificationSent;

  /// No description provided for @activityLabelNotificationDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Удалено уведомление'**
  String get activityLabelNotificationDeleted;

  /// No description provided for @activityLabelDeviceRegistered.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь вошёл'**
  String get activityLabelDeviceRegistered;

  /// No description provided for @activityLabelDeviceUnregistered.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь вышел'**
  String get activityLabelDeviceUnregistered;

  /// No description provided for @activityLabelDayNoteSet.
  ///
  /// In ru, this message translates to:
  /// **'Заметка сохранена'**
  String get activityLabelDayNoteSet;

  /// No description provided for @activityLabelDayNoteDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Заметка удалена'**
  String get activityLabelDayNoteDeleted;

  /// No description provided for @activityFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get activityFilterAll;

  /// No description provided for @activityFilterUsers.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get activityFilterUsers;

  /// No description provided for @activityFilterNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get activityFilterNotifications;

  /// No description provided for @activityFilterNotes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки'**
  String get activityFilterNotes;

  /// No description provided for @activityFilterSecurity.
  ///
  /// In ru, this message translates to:
  /// **'Безопасность'**
  String get activityFilterSecurity;

  /// No description provided for @bytesB.
  ///
  /// In ru, this message translates to:
  /// **'{value} Б'**
  String bytesB(String value);

  /// No description provided for @bytesKb.
  ///
  /// In ru, this message translates to:
  /// **'{value} КБ'**
  String bytesKb(String value);

  /// No description provided for @bytesMb.
  ///
  /// In ru, this message translates to:
  /// **'{value} МБ'**
  String bytesMb(String value);

  /// No description provided for @bytesGb.
  ///
  /// In ru, this message translates to:
  /// **'{value} ГБ'**
  String bytesGb(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
