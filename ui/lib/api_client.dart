import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'main.dart' show navigatorKey;
import 'models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String get _baseUrl => AppConfig.apiBaseUrl;
  String? _token;
  String? _refreshToken;
  bool _isRefreshing = false;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    _token = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  bool get isLoggedIn => _token != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Try to refresh the access token using the stored refresh token.
  /// Returns true if refresh succeeded.
  Future<bool> _tryRefresh() async {
    if (_refreshToken == null || _isRefreshing) return false;
    _isRefreshing = true;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        await _saveTokens(data['access_token'], data['refresh_token']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Clear tokens and redirect to login when session is unrecoverable.
  Future<void> _handleAuthFailure() async {
    await clearToken();
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your session has expired. Please sign in again.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  /// Execute a request, automatically refreshing the token on 401.
  Future<http.Response> _authGet(Uri url) async {
    var response = await http.get(url, headers: _headers);
    if (response.statusCode == 401) {
      if (await _tryRefresh()) {
        response = await http.get(url, headers: _headers);
      } else {
        await _handleAuthFailure();
      }
    }
    return response;
  }

  Future<http.Response> _authPost(Uri url, {Object? body}) async {
    var response = await http.post(url, headers: _headers, body: body);
    if (response.statusCode == 401) {
      if (await _tryRefresh()) {
        response = await http.post(url, headers: _headers, body: body);
      } else {
        await _handleAuthFailure();
      }
    }
    return response;
  }

  Future<http.Response> _authDelete(Uri url) async {
    var response = await http.delete(url, headers: _headers);
    if (response.statusCode == 401) {
      if (await _tryRefresh()) {
        response = await http.delete(url, headers: _headers);
      } else {
        await _handleAuthFailure();
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }
    String message = 'Request failed';
    try {
      final body = jsonDecode(response.body);
      message = body['detail'] ?? message;
    } catch (_) {}
    throw ApiException(response.statusCode, message);
  }

  List<dynamic> _handleListResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return [];
      return jsonDecode(response.body) as List;
    }
    String message = 'Request failed';
    try {
      final body = jsonDecode(response.body);
      message = body['detail'] ?? message;
    } catch (_) {}
    throw ApiException(response.statusCode, message);
  }

  // --- Auth ---

  Future<({String token, User user})> register(String email, String displayName, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'email': email, 'display_name': displayName, 'password': password}),
    );
    final data = await _handleResponse(response);
    await _saveTokens(data['access_token'] as String, data['refresh_token'] as String);
    return (token: data['access_token'] as String, user: User.fromJson(data['user']));
  }

  Future<({String token, User user})> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(response);
    await _saveTokens(data['access_token'] as String, data['refresh_token'] as String);
    return (token: data['access_token'] as String, user: User.fromJson(data['user']));
  }

  // --- Gratitude ---

  Future<List<GratitudeEntry>> getMyGratitudes({int limit = 30, int offset = 0}) async {
    final response = await _authGet(
      Uri.parse('$_baseUrl/gratitudes?limit=$limit&offset=$offset'),
    );
    final list = _handleListResponse(response);
    return list.map((e) => GratitudeEntry.fromJson(e)).toList();
  }

  Future<GratitudeEntry> createGratitude(String title, String? description, {String? entryDate}) async {
    final body = <String, dynamic>{'title': title, 'description': description};
    if (entryDate != null) body['entry_date'] = entryDate;
    final response = await _authPost(
      Uri.parse('$_baseUrl/gratitudes'),
      body: jsonEncode(body),
    );
    final data = await _handleResponse(response);
    return GratitudeEntry.fromJson(data);
  }

  Future<void> deleteGratitude(String id) async {
    final response = await _authDelete(
      Uri.parse('$_baseUrl/gratitudes/$id'),
    );
    if (response.statusCode != 204) {
      await _handleResponse(response);
    }
  }

  // --- Feed ---

  Future<List<GratitudeEntry>> getFeed({int limit = 30, int offset = 0}) async {
    final response = await _authGet(
      Uri.parse('$_baseUrl/gratitudes/feed?limit=$limit&offset=$offset'),
    );
    final list = _handleListResponse(response);
    return list.map((e) => GratitudeEntry.fromJson(e)).toList();
  }

  // --- Users ---

  Future<User> getMe() async {
    final response = await _authGet(
      Uri.parse('$_baseUrl/users/me'),
    );
    final data = await _handleResponse(response);
    return User.fromJson(data);
  }

  Future<List<User>> getUsers() async {
    final response = await _authGet(
      Uri.parse('$_baseUrl/users'),
    );
    final list = _handleListResponse(response);
    return list.map((e) => User.fromJson(e)).toList();
  }

  Future<List<GratitudeEntry>> getUserGratitudes(String userId) async {
    final response = await _authGet(
      Uri.parse('$_baseUrl/users/$userId/gratitudes'),
    );
    final list = _handleListResponse(response);
    return list.map((e) => GratitudeEntry.fromJson(e)).toList();
  }

  // --- Streaks ---

  Future<Streak> getMyStreak() async {
    final response = await _authGet(
      Uri.parse('$_baseUrl/streaks/me'),
    );
    final data = await _handleResponse(response);
    return Streak.fromJson(data);
  }
}
