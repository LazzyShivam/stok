import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_id';
  final _storage = const FlutterSecureStorage();
  final ApiService _api;

  AuthService(this._api);

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<String?> getUserId() => _storage.read(key: _userKey);

  Future<void> saveToken(String token, String userId) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: userId);
    _api.setToken(token);
  }

  Future<void> clearToken() async {
    await _storage.deleteAll();
    _api.clearToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> sendOtp(String phone) async {
    await _api.post('/auth/send-otp', data: {'phone': phone});
  }

  Future<({String token, UserModel user, bool isNewUser})> verifyOtp(
    String phone,
    String otp,
  ) async {
    final response = await _api.post('/auth/verify-otp', data: {'phone': phone, 'otp': otp});
    final token = response['token'] as String;
    final user = UserModel.fromJson(response['user'] as Map<String, dynamic>);
    final isNewUser = response['isNewUser'] as bool? ?? false;
    await saveToken(token, user.id);
    return (token: token, user: user, isNewUser: isNewUser);
  }

  Future<void> logout() => clearToken();
}
