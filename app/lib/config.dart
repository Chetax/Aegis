// lib/config.dart  (new file)
class AppConfig {
  static const String backendHost = '192.168.0.4';  // update in ONE place
  static const int backendPort = 8000;
  static String get httpBase => 'http://$backendHost:$backendPort';
  static String get wsBase => 'ws://$backendHost:$backendPort';
}