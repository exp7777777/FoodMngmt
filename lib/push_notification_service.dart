import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';
import 'models.dart';

/// Web 端推播需要的 VAPID Key，可透過 `--dart-define` 傳入。
const String _webPushKey = String.fromEnvironment(
  'FOODMNGMT_WEB_PUSH_KEY',
  defaultValue:
      'BKWksq8QyYLKtXHaYhPlPxuho-ul4mAyqoL3XDbXF2n-QXmGmqyzXEl7MFbBDELD85G-ImuVNIKjzMKyZ5i92cY',
);
const String _fallbackTimeZone = String.fromEnvironment(
  'FOODMNGMT_TZ',
  defaultValue: 'Asia/Taipei',
);
const Duration _autoRescheduleInterval = Duration(seconds: 30);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // 已初始化時會拋例外，忽略即可。
  }
  debugPrint('背景收到推播：${message.messageId ?? message.data}');
  await PushNotificationService.instance.handleRemoteMessage(
    message,
    fromBackground: true,
  );
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<User?>? _authStateSub;

  bool _initialized = false;
  bool _localNotificationsReady = false;
  bool _timezoneInitialized = false;
  Timer? _rescheduleTimer;
  List<FoodItem> _cachedItems = [];

  String? _currentToken;
  String? _currentUserId;

  NotificationSettings? lastPermissionSettings;

  static const int _expiryReminderBaseId = 5000;
  static const int _maxExpiryReminders = 10;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'foodmngmt_high_priority',
        '食材提醒通知',
        description: '食材即將到期與購物清單更新的推播訊息',
        importance: Importance.high,
      );

  bool get _isMessagingSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_isMessagingSupported) {
      debugPrint('當前平台不支援 Firebase Messaging，略過初始化。');
      return;
    }

    _messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _ensureLocalNotifications();
    await _requestPermissions();
    await _configureForegroundPresentation();
    await _listenForInitialMessage();
    _registerMessageHandlers();
    _listenAuthChanges();
    _listenTokenRefresh();
    await _syncDeviceToken();

    _initialized = true;
  }

  NotificationDetails get _defaultNotificationDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
    ),
    iOS: const DarwinNotificationDetails(),
    macOS: const DarwinNotificationDetails(),
  );

  Future<void> _ensureLocalNotifications() async {
    if (kIsWeb || _localNotificationsReady) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );

    final initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotificationsPlugin.initialize(initializationSettings);
    final androidPlugin =
        _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    await _ensureTimezone();

    _localNotificationsReady = true;
  }

  Future<void> _ensureTimezone() async {
    if (_timezoneInitialized || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(_resolveTimezoneLocation());
      _timezoneInitialized = true;
    } catch (e) {
      debugPrint('初始化時區資料失敗：$e');
    }
  }

  tz.Location _resolveTimezoneLocation() {
    final candidates = <String?>[
      _mapTimeZoneName(DateTime.now().timeZoneName),
      _fallbackTimeZone,
      'UTC',
    ];

    for (final name in candidates) {
      if (name == null) continue;
      try {
        return tz.getLocation(name);
      } catch (_) {
        continue;
      }
    }

    return tz.getLocation('UTC');
  }

  String? _mapTimeZoneName(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('taipei')) return 'Asia/Taipei';
    if (normalized.contains('hong') && normalized.contains('kong')) {
      return 'Asia/Hong_Kong';
    }
    if (normalized.contains('shanghai') ||
        normalized.contains('beijing') ||
        normalized.contains('china')) {
      return 'Asia/Shanghai';
    }
    if (normalized.contains('tokyo') || normalized.contains('japan')) {
      return 'Asia/Tokyo';
    }
    if (normalized.contains('singapore')) return 'Asia/Singapore';
    if (normalized.contains('los') && normalized.contains('angeles')) {
      return 'America/Los_Angeles';
    }
    if (normalized.contains('new') && normalized.contains('york')) {
      return 'America/New_York';
    }
    if (normalized.contains('utc') || normalized.contains('gmt')) {
      return 'UTC';
    }
    return null;
  }

  Future<void> _requestPermissions() async {
    final messaging = _messaging;
    if (messaging == null) return;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
      );
      lastPermissionSettings = settings;
      debugPrint('推播權限：${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('推播權限請求失敗：$e');
    }
  }

  Future<void> _configureForegroundPresentation() async {
    final messaging = _messaging;
    if (messaging == null) return;

    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('設定前景通知樣式失敗：$e');
    }
  }

  Future<void> _listenForInitialMessage() async {
    final messaging = _messaging;
    if (messaging == null) return;

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('應用程式由推播啟動：${initialMessage.messageId}');
    }
  }

  void _registerMessageHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await handleRemoteMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('使用者點擊推播：${message.messageId}');
    });
  }

  void _listenTokenRefresh() {
    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((
      String token,
    ) async {
      _currentToken = token;
      await _persistToken(token);
    });
  }

  void _listenAuthChanges() {
    _authStateSub ??= FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) async {
      final previousUser = _currentUserId;
      _currentUserId = user?.uid;

      if (user == null) {
        if (previousUser != null && _currentToken != null) {
          await _removeToken(previousUser, _currentToken!);
        }
        return;
      }

      await _syncDeviceToken();
    });
  }

  Future<void> _syncDeviceToken() async {
    final messaging = _messaging;
    if (messaging == null) return;

    if (kIsWeb && _webPushKey.isEmpty) {
      debugPrint('未提供 Web Push VAPID Key，略過 Web token 產生。');
      return;
    }

    try {
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? _webPushKey : null,
      );
      if (token == null) return;
      _currentToken = token;
      await _persistToken(token);
    } catch (e) {
      debugPrint('取得 FCM Token 失敗：$e');
    }
  }

  Future<void> _persistToken(String token) async {
    final userId = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    final tokensCollection = userDoc.collection('deviceTokens');

    final metadata = {
      'token': token,
      'platform': _platformLabel,
      'locale': ui.PlatformDispatcher.instance.locale.toLanguageTag(),
      'timezone': DateTime.now().timeZoneName,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await tokensCollection.doc(token).set({
        ...metadata,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await userDoc.set({
        'latestFcmToken': token,
        'notifications': metadata,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('儲存 FCM Token 失敗：$e');
    }
  }

  Future<void> _removeToken(String userId, String token) async {
    final tokenDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('deviceTokens')
        .doc(token);
    try {
      await tokenDoc.delete();
    } catch (e) {
      debugPrint('移除舊 token 失敗：$e');
    }
  }

  Future<void> handleRemoteMessage(
    RemoteMessage message, {
    bool fromBackground = false,
  }) async {
    debugPrint(
      '[PushNotification] 收到 Firebase 訊息：id=${message.messageId} background=$fromBackground',
    );
    final notification = message.notification;

    if (notification != null && !kIsWeb && !fromBackground) {
      await _showLocalNotification(
        title: notification.title ?? 'FoodMngmt',
        body: notification.body ?? '',
        data: message.data,
      );
      return;
    }

    if (!kIsWeb && !fromBackground && notification == null) {
      final title = message.data['title'] as String? ?? 'FoodMngmt 資訊提醒';
      final body = message.data['body'] as String? ?? '你有新的食材或購物清單更新。';
      await _showLocalNotification(
        title: title,
        body: body,
        data: message.data,
      );
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (kIsWeb) return;
    await _ensureLocalNotifications();
    debugPrint('[PushNotification] 顯示通知：$title - $body');

    await _localNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      _defaultNotificationDetails,
      payload: data == null || data.isEmpty ? null : jsonEncode(data),
    );
  }

  Future<void> refreshExpiryReminders(List<FoodItem> items) async {
    if (!isInitialized) {
      debugPrint('PushNotificationService 尚未初始化，略過到期排程');
      return;
    }
    if (kIsWeb) return;
    _cachedItems = List<FoodItem>.from(items);
    if (_cachedItems.isEmpty) {
      await _cancelExpiryReminders();
      _cancelAutoReschedule();
      return;
    }

    await _scheduleExpiryReminders(_cachedItems);
    _restartAutoReschedule();
  }

  Future<void> _scheduleExpiryReminders(
    List<FoodItem> items, {
    bool fromAutoTimer = false,
  }) async {
    if (kIsWeb || items.isEmpty) return;
    await _ensureLocalNotifications();
    await _ensureTimezone();

    try {
      await _cancelExpiryReminders();

      final now = DateTime.now();
      final expiringItems =
          items.where((item) {
              final diff = item.expiryDate.difference(now).inDays;
              return diff >= 0 && diff <= 3;
            }).toList()
            ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

      if (expiringItems.isEmpty) {
        _cancelAutoReschedule();
        return;
      }

      final formatter = DateFormat('yyyy-MM-dd');

      for (
        var i = 0;
        i < expiringItems.length && i < _maxExpiryReminders;
        i++
      ) {
        final item = expiringItems[i];
        var scheduledTime = DateTime(
          item.expiryDate.year,
          item.expiryDate.month,
          item.expiryDate.day,
          9,
        ).subtract(const Duration(days: 1));

        final min = DateTime.now().add(const Duration(minutes: 1));
        if (scheduledTime.isBefore(min)) {
          scheduledTime = min;
        }

        final scheduleDate = tz.TZDateTime.from(scheduledTime, tz.local);

        await _localNotificationsPlugin.zonedSchedule(
          _expiryReminderBaseId + i,
          '${item.name} 即將到期',
          '到期日：${formatter.format(item.expiryDate)}',
          scheduleDate,
          _defaultNotificationDetails,
          payload: jsonEncode({
            'type': 'expiry',
            'foodId': item.id ?? '',
            'expiresAt': item.expiryDate.toIso8601String(),
          }),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );

        debugPrint(
          '[PushNotification] 排程${fromAutoTimer ? '自動' : '即時'}提醒：${item.name} -> ${formatter.format(item.expiryDate)} @ ${scheduleDate.toLocal()}',
        );
      }
    } catch (e) {
      debugPrint('排程到期提醒失敗：$e');
    }
  }

  void _restartAutoReschedule() {
    _rescheduleTimer?.cancel();
    if (_cachedItems.isEmpty) return;
    _rescheduleTimer = Timer.periodic(_autoRescheduleInterval, (_) {
      if (!isInitialized || _cachedItems.isEmpty) return;
      scheduleMicrotask(() {
        _scheduleExpiryReminders(_cachedItems, fromAutoTimer: true);
      });
    });
  }

  void _cancelAutoReschedule() {
    _rescheduleTimer?.cancel();
    _rescheduleTimer = null;
  }

  Future<void> _cancelExpiryReminders() async {
    if (kIsWeb) return;
    final pending =
        await _localNotificationsPlugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= _expiryReminderBaseId &&
          request.id < _expiryReminderBaseId + _maxExpiryReminders) {
        await _localNotificationsPlugin.cancel(request.id);
      }
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    if (_messaging == null) return;
    try {
      await _messaging!.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('訂閱 Topic $topic 失敗：$e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (_messaging == null) return;
    try {
      await _messaging!.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('取消訂閱 Topic $topic 失敗：$e');
    }
  }

  String get _platformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return defaultTargetPlatform.name;
    }
  }
}
