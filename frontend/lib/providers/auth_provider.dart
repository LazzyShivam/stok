import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiService _apiService;

  AuthState _state = AuthState.initial;
  UserModel? _currentUser;
  String? _error;

  AuthProvider(this._authService, this._apiService);

  AuthState get state => _state;
  UserModel? get currentUser => _currentUser;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;

  Future<void> initialize() async {
    _state = AuthState.loading;
    notifyListeners();

    final token = await _authService.getToken();
    if (token == null) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    _apiService.setToken(token);

    try {
      final userData = await _apiService.get('/users/me');
      _currentUser = UserModel.fromJson(userData as Map<String, dynamic>);
      _state = AuthState.authenticated;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        // Token is invalid or expired — clear it and go to login
        await _authService.clearToken();
        _state = AuthState.unauthenticated;
      } else {
        // Network error or server down — keep token, assume still authenticated
        // so the user isn't kicked to login when they're just offline
        _state = AuthState.authenticated;
      }
    } catch (_) {
      // Unexpected error — keep authenticated state, don't clear token
      _state = AuthState.authenticated;
    }

    notifyListeners();
  }

  Future<void> sendOtp(String phone) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      await _authService.sendOtp(phone);
      _state = AuthState.unauthenticated;
    } catch (e) {
      _error = _friendlyError(e);
      _state = AuthState.error;
    }
    notifyListeners();
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await _authService.verifyOtp(phone, otp);
      _currentUser = result.user;
      _state = AuthState.authenticated;
      notifyListeners();
      return result.isNewUser;
    } catch (e) {
      _error = _friendlyError(e);
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({String? name, String? bio}) async {
    try {
      final updated = await _apiService.patch('/users/me', data: {
        if (name != null) 'name': name,
        if (bio != null) 'bio': bio,
      });
      _currentUser = UserModel.fromJson(updated as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) return 'Connection timed out. Check your network.';
      if (e.type == DioExceptionType.connectionError) return 'Cannot reach server. Check your connection.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
