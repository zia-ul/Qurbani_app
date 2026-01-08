import 'package:permission_handler/permission_handler.dart';

class PermissionService {

  static Future<bool> hasPermissions() async {
    final location = await Permission.location.status;
    final camera = await Permission.camera.status;
    final photos = await Permission.photos.status; // iOS/Android 13+
    
    return location.isGranted && camera.isGranted && photos.isGranted;
  }

  static Future<bool> requestPermissions() async {
    final result = await [
      Permission.location,
      Permission.camera,
      Permission.photos,
    ].request();

    return result.values.every((status) => status.isGranted);
  }

  static Future<bool> permanentlyDenied() async {
    return await Permission.location.isPermanentlyDenied ||
           await Permission.camera.isPermanentlyDenied ||
           await Permission.photos.isPermanentlyDenied;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
