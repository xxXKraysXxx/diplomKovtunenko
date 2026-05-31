import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:ncti_schedule_client/api/graphql_config.dart';
import 'package:ncti_schedule_client/models/app_user.dart';
import 'package:ncti_schedule_client/models/notification_item.dart';
import 'package:ncti_schedule_client/state/notifications.dart';

class _FakeUnreadCount extends UnreadCount {
  @override
  Future<int> build() async => 2;
}

class _FakeNotificationsList extends NotificationsList {
  _FakeNotificationsList(this.seed);
  final List<NotificationItem> seed;

  @override
  Future<List<NotificationItem>> build() async => seed;
}

class _RecordingClient implements GraphQLClient {
  int mutateCalls = 0;

  @override
  Future<QueryResult<TParsed>> mutate<TParsed>(
      MutationOptions<TParsed> options) async {
    mutateCalls += 1;
    return QueryResult<TParsed>(
      options: options,
      data: const {'markAllNotificationsRead': true},
      source: QueryResultSource.network,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container({
  required _RecordingClient client,
  required List<NotificationItem> seed,
}) {
  final c = ProviderContainer(overrides: [
    graphqlClientProvider.overrideWithValue(client),
    unreadCountProvider.overrideWith(_FakeUnreadCount.new),
    notificationsProvider.overrideWith(() => _FakeNotificationsList(seed)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('autoMarkAllRead marks local rows and clears badge', () async {
    final client = _RecordingClient();
    final c = _container(client: client, seed: [
      _notification(1, isRead: false),
      _notification(2, isRead: true),
    ]);
    await c.read(notificationsProvider.future);
    await c.read(unreadCountProvider.future);

    await c.read(notificationsProvider.notifier).autoMarkAllRead();

    expect(client.mutateCalls, 1);
    expect(c.read(unreadCountProvider).asData?.value, 0);
    final rows = c.read(notificationsProvider).asData!.value;
    expect(rows.map((n) => n.isRead), [true, true]);
  });

  test('autoMarkAllRead still calls server when cache has no unread rows',
      () async {
    final client = _RecordingClient();
    final c = _container(client: client, seed: [
      _notification(1, isRead: true),
    ]);
    await c.read(notificationsProvider.future);

    await c.read(notificationsProvider.notifier).autoMarkAllRead();

    expect(client.mutateCalls, 1);
  });
}

NotificationItem _notification(int id, {required bool isRead}) {
  return NotificationItem(
    id: id,
    senderUserId: 1,
    sender: const NotificationSender(
      id: 1,
      login: 'admin',
      role: UserRole.admin,
      accentColor: null,
    ),
    scope: NotificationScope.global,
    body: 'n$id',
    linkedDate: null,
    targetGroupIds: const [],
    createdAt: DateTime(2026, 5, 3),
    isRead: isRead,
  );
}
