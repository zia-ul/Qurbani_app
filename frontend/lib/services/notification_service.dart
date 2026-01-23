import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _baseUrl = 'http://192.168.1.4:3000/api';

  static void startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      await _checkNotifications();
      return true;
    });
  }

  static Future<void> _checkNotifications() async {
    final res = await http.get(Uri.parse('$_baseUrl/notifications/unread'));

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;

      for (final n in list) {
        _local.show(
          n['id'],
          n['title'],
          n['body'],
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'qurbani_channel',
              'Qurbani Notifications',
              importance: Importance.max,
            ),
          ),
        );
      }
    }
  }
}
