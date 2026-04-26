import 'package:Qurbani/services/phone_email_config.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:phone_email_auth/phone_email_auth.dart';
import 'wrapper_screen.dart';
import 'theme/theme.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const String qurbaniNotificationChannelId = 'qurbani_channel';
bool _oneSignalHandlersAttached = false;

void _configureOneSignalHandlers() {
  if (_oneSignalHandlersAttached) {
    return;
  }

  _oneSignalHandlersAttached = true;

  OneSignal.Notifications.addPermissionObserver((permission) {
    debugPrint('[push] permission=$permission');
    AppLogger.info('OneSignal permission changed: $permission');
  });

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    final notification = event.notification;
    final title = notification.title ?? '';
    final body = notification.body ?? '';

    debugPrint(
      '[push] foreground notification id=${notification.notificationId} '
      'title=$title body=$body data=${notification.additionalData}',
    );
    AppLogger.info(
      'Foreground push received: id=${notification.notificationId}, title=$title',
    );

    // Keep showing the system notification while the app is open.
    event.preventDefault();
    notification.display();
  });

  OneSignal.Notifications.addClickListener((event) {
    final notification = event.notification;

    debugPrint(
      '[push] notification clicked id=${notification.notificationId} '
      'data=${notification.additionalData}',
    );
    AppLogger.info(
      'Push notification clicked: id=${notification.notificationId}',
    );
  });
}

Future<void> _logCurrentPushState() async {
  final subscription = OneSignal.User.pushSubscription;
  final permission = OneSignal.Notifications.permission;

  debugPrint(
    '[push] startup permission=$permission '
    'subscriptionId=${subscription.id} '
    'optedIn=${subscription.optedIn} '
    'tokenPresent=${subscription.token != null}',
  );
  AppLogger.info(
    'OneSignal startup state: permission=$permission, '
    'subscriptionId=${subscription.id}, optedIn=${subscription.optedIn}, '
    'tokenPresent=${subscription.token != null}',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await currencyService.initialize(); // Fetch rates and load cached data
  await AppLogger.init();
  await dotenv.load(fileName: "assets/.env");

  /// Local notifications initialization
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  if (PhoneEmailConfig.isConfigured) {
    await PhoneEmail.initializeApp(clientId: PhoneEmailConfig.clientId);
    AppLogger.info('Phone.Email initialized successfully');
  } else {
    AppLogger.warning(
      'Phone.Email skipped because PHONE_EMAIL_CLIENT_ID is missing in assets/.env',
    );
  }

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {},
  );

  /// Android notification channel (used by backend-triggered notifications)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    qurbaniNotificationChannelId,
    'Qurbani Notifications',
    description: 'Centralized notifications from backend',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  /// Awesome Notifications
  AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'admin_alerts',
      channelName: 'Admin Alerts',
      channelDescription: 'Admin dashboard notifications',
      defaultColor: AppTheme.primaryGreen,
      importance: NotificationImportance.Max,
      channelShowBadge: true,
      enableVibration: true,
      playSound: true,
    ),

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
  ], debug: true);

  /// ✅ Initialize OneSignal FIRST
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  OneSignal.initialize(dotenv.env['APP_ID_ONE_SIGNAL']!);

  _configureOneSignalHandlers();

  final permissionGranted = await OneSignal.Notifications.requestPermission(
    true,
  );
  debugPrint('[push] permission request result=$permissionGranted');
  AppLogger.info('OneSignal permission request result: $permissionGranted');

  await Future<void>.delayed(const Duration(milliseconds: 500));
  await _logCurrentPushState();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // title: 'Qurbani App',

      /// Centralized Theme (Now Active)
      theme: AppTheme.lightTheme,

      // darkTheme: AppTheme.darkTheme,
      // themeMode: ThemeMode.system,
      home: WrapperScreen(),
      // home: const WelcomeScreen(),

      /// Global Gradient Wrapper for All Screens
      builder: (context, child) {
        return GlobalGradientWrapper(child: child!);
      },
    );
  }
}

// Global Gradient Wrapper Widget
class GlobalGradientWrapper extends StatelessWidget {
  final Widget child;

  const GlobalGradientWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Dynamically select gradient based on theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? AppTheme.darkBackgroundGradient
        : AppTheme.lightBackgroundGradient;

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: child, // Wraps the entire app/screen
    );
  }
}
