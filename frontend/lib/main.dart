import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:qurbani/theme/theme.dart';
import 'package:qurbani/welcome_screen.dart';
import 'wrapper_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Load environment variables
  // await dotenv.load(fileName: "lib/user/.env");

  /// Local notifications initialization
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      debugPrint("Notification clicked: ${details.payload}");
    },
  );

  /// Android notification channel (used by backend-triggered notifications)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'qurbani_channel',
    'Qurbani Notifications',
    description: 'Centralized notifications from backend',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  /// Awesome Notifications (optional but fine)
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'General notifications',
        defaultColor: AppTheme.primaryGreen,
        importance: NotificationImportance.High,
        channelShowBadge: true,
      ),
      NotificationChannel(
        channelKey: 'order_updates',
        channelName: 'Order Updates',
        channelDescription: 'Order status updates',
        defaultColor: AppTheme.primaryGreen,
        importance: NotificationImportance.Max,
        channelShowBadge: true,
        enableVibration: true,
      ),
    ],
    debug: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Qurbani App',

      /// Centralized Theme
      // theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      home: const WrapperScreen(),
      // home: const WelcomeScreen(),
    );
  }
}
