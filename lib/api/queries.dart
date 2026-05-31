const String raspisanieQuery = r'''
query Raspisanie(
  $groups: [Int!]
  $teachers: [Int!]
  $classrooms: [String!]
  $from: String
  $to: String
) {
  raspisanie(
    IdGroups: $groups
    IdTeachers: $teachers
    Classrooms: $classrooms
    from: $from
    to: $to
  ) {
    date
    subjectNumber
    subgroup
    classroom
    isOverride
    groupBy { id name }
    teacherBy { id name }
    subjectBy { id name }
  }
}
''';

const String groupsQuery = r'''
query Groups {
  group {
    id
    name
    course
  }
}
''';

const String teachersQuery = r'''
query Teachers {
  teacher {
    id
    name
  }
}
''';

const String classroomsQuery = r'''
query Classrooms {
  classrooms
}
''';

const String dayNoteQuery = r'''
query DayNote($date: String!) {
  dayNote(date: $date) {
    id
    date
    body
    updatedAt
  }
}
''';

const String dayNotesRangeQuery = r'''
query DayNotes($from: String!, $to: String!) {
  dayNotes(from: $from, to: $to) {
    id
    date
    body
    updatedAt
  }
}
''';

const String setDayNoteMutation = r'''
mutation SetDayNote($date: String!, $body: String!) {
  setDayNote(date: $date, body: $body) {
    id
    date
    body
    updatedAt
  }
}
''';

const String deleteDayNoteMutation = r'''
mutation DeleteDayNote($date: String!) {
  deleteDayNote(date: $date)
}
''';

const String meQuery = r'''
query Me {
  me {
    id
    login
    role
    groupId
    teacherId
    canPush
    canBroadcastGlobally
    accentColor
    lastActivityAt
    createdAt
  }
}
''';

const String loginMutation = r'''
mutation Login($login: String!, $password: String!) {
  login(login: $login, password: $password) {
    token
    user {
      id
      login
      role
      groupId
      teacherId
      canPush
      canBroadcastGlobally
      lastActivityAt
      createdAt
    }
    defaultFilter {
      groupIds
      teacherIds
    }
  }
}
''';

const String registerStudentMutation = r'''
mutation RegisterStudent($login: String!, $password: String!, $groupId: Int!) {
  registerStudent(login: $login, password: $password, groupId: $groupId) {
    token
    user {
      id
      login
      role
      groupId
      teacherId
      canPush
      canBroadcastGlobally
      lastActivityAt
      createdAt
    }
    defaultFilter {
      groupIds
      teacherIds
    }
  }
}
''';

const String changePasswordMutation = r'''
mutation ChangePassword($currentPassword: String!, $newPassword: String!) {
  changePassword(currentPassword: $currentPassword, newPassword: $newPassword)
}
''';

const String usersQuery = r'''
query Users($role: UserRole) {
  users(role: $role) {
    id
    login
    role
    groupId
    teacherId
    canPush
    canBroadcastGlobally
    accentColor
    lastActivityAt
    createdAt
    storage {
      noteBytes
      notificationBytes
      deviceTokenCount
      totalBytes
    }
  }
}
''';

const String setUserCanBroadcastGloballyMutation = r'''
mutation SetUserCanBroadcastGlobally($userId: Int!, $enabled: Boolean!) {
  setUserCanBroadcastGlobally(userId: $userId, enabled: $enabled) {
    id
    login
    role
    canPush
    canBroadcastGlobally
  }
}
''';

const String runNewsScrapeMutation = r'''
mutation RunNewsScrape {
  runNewsScrape
}
''';

const String serverActivityQuery = r'''
query ServerActivity($limit: Int, $action: String) {
  serverActivity {
    registrations
    failedLogins
    passwordResets
    notificationsSent
    countsByAction {
      action
      count
    }
    recentEvents(limit: $limit, action: $action) {
      id
      userId
      userLogin
      action
      details
      ip
      createdAt
    }
  }
}
''';

const String createTeacherMutation = r'''
mutation CreateTeacher($login: String!, $password: String!, $teacherId: Int!) {
  createTeacher(login: $login, password: $password, teacherId: $teacherId) {
    id
    login
    role
    groupId
    teacherId
    canPush
    accentColor
    lastActivityAt
    createdAt
  }
}
''';

const String createAdminMutation = r'''
mutation CreateAdmin($login: String!, $password: String!) {
  createAdmin(login: $login, password: $password) {
    id
    login
    role
    groupId
    teacherId
    canPush
    accentColor
    lastActivityAt
    createdAt
  }
}
''';

const String deleteUserMutation = r'''
mutation DeleteUser($id: Int!) {
  deleteUser(id: $id)
}
''';

const String setTeacherPushMutation = r'''
mutation SetTeacherPush($teacherUserId: Int!, $canPush: Boolean!) {
  setTeacherPushPermission(teacherUserId: $teacherUserId, canPush: $canPush) {
    id
    login
    role
    canPush
  }
}
''';

const String adminResetPasswordMutation = r'''
mutation AdminResetPassword($userId: Int!, $newPassword: String!) {
  adminResetPassword(userId: $userId, newPassword: $newPassword)
}
''';

const String setAccentColorMutation = r'''
mutation SetAccentColor($color: String) {
  setAccentColor(color: $color) {
    id
    login
    role
    groupId
    teacherId
    canPush
    accentColor
    lastActivityAt
    createdAt
  }
}
''';

const String _notificationFragment = r'''
  id
  senderUserId
  sender { id login role accentColor }
  scope
  body
  linkedDate
  targetGroupIds
  createdAt
  isRead
''';

final String notificationsQuery = '''
query Notifications(\$unreadOnly: Boolean) {
  notifications(unreadOnly: \$unreadOnly) {
$_notificationFragment
  }
}
''';

final String notificationsForDatesQuery = '''
query NotificationsForDates(\$from: String!, \$to: String!) {
  notificationsForDates(from: \$from, to: \$to) {
$_notificationFragment
  }
}
''';

final String sendNotificationMutation = '''
mutation SendNotification(
  \$scope: NotificationScope!,
  \$groupIds: [Int!],
  \$body: String!,
  \$linkedDate: String
) {
  sendNotification(
    scope: \$scope,
    groupIds: \$groupIds,
    body: \$body,
    linkedDate: \$linkedDate
  ) {
$_notificationFragment
  }
}
''';

const String markNotificationReadMutation = r'''
mutation MarkNotificationRead($id: Int!) {
  markNotificationRead(id: $id)
}
''';

const String markAllNotificationsReadMutation = r'''
mutation MarkAllNotificationsRead {
  markAllNotificationsRead
}
''';

const String deleteNotificationMutation = r'''
mutation DeleteNotification($id: Int!) {
  deleteNotification(id: $id)
}
''';

const String registerDeviceTokenMutation = r'''
mutation RegisterDeviceToken($token: String!, $platform: String!) {
  registerDeviceToken(token: $token, platform: $platform)
}
''';

const String unregisterDeviceTokenMutation = r'''
mutation UnregisterDeviceToken($token: String!) {
  unregisterDeviceToken(token: $token)
}
''';

const String newsQuery = r'''
query News($limit: Int) {
  news(limit: $limit) {
    id
    title
    excerpt
    imageUrl
    sourceUrl
    publishedAt
    fetchedAt
    bodyText
    bodyHtml
  }
}
''';

const String devicePushPrefsQuery = r'''
query DevicePushPrefs($deviceToken: String!) {
  devicePushPrefs(deviceToken: $deviceToken) {
    deviceToken
    news
    announcements
    scheduleChanges
    updatedAt
  }
}
''';

const String updateDevicePushPrefsMutation = r'''
mutation UpdateDevicePushPrefs(
  $deviceToken: String!,
  $prefs: DevicePushPrefsInput!
) {
  updateDevicePushPrefs(deviceToken: $deviceToken, prefs: $prefs) {
    deviceToken
    news
    announcements
    scheduleChanges
    updatedAt
  }
}
''';

const String _pinnedDayNoteFragment = r'''
  notificationId
  sender { id login role accentColor }
  body
  linkedDate
  createdAt
''';

final String pinnedNotesForDateQuery = '''
query PinnedNotesForDate(\$date: String!) {
  pinnedNotesForDate(date: \$date) {
$_pinnedDayNoteFragment
  }
}
''';

final String pinnedNotesInRangeQuery = '''
query PinnedNotesInRange(\$from: String!, \$to: String!) {
  pinnedNotesInRange(from: \$from, to: \$to) {
$_pinnedDayNoteFragment
  }
}
''';

const String appSettingsQuery = r'''
query AppSettings {
  appSettings {
    teachersCanBroadcastGlobally
  }
}
''';

const String updateAdminSettingMutation = r'''
mutation UpdateAdminSetting($key: String!, $value: String!) {
  updateAdminSetting(key: $key, value: $value)
}
''';
