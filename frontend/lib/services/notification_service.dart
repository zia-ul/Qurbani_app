import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static final String? _baseUrl =  dotenv.env['BASE_URL'];

  static void startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      await _checkNotifications();
      return true;
    });
  }

  /**
   * Checks for unread notifications from the backend
   *
   * Fetches unread notifications from the server and displays them as local
   * push notifications using Flutter Local Notifications. Each notification
   * is shown with its title and body content. This method is called
   * periodically by the polling mechanism.
   */
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
