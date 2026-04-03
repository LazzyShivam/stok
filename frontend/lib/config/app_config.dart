class AppConfig {
  static const String appName = 'Stok';

  // Change this to your backend URL
  static const String baseUrl = 'https://stok-production-f0d9.up.railway.app';
  static const String apiUrl = '$baseUrl/api';
  static const String socketUrl = baseUrl;
  static const String uploadUrl = baseUrl;

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // Pagination
  static const int messagePageSize = 50;
  static const int listPageSize = 20;

  // Call
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];
}
