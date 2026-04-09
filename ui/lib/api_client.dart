import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
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

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  bool get isLoggedIn => _token != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

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

  // --- Auth ---

  Future<({String token, User user})> register(String email, String displayName, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'email': email, 'display_name': displayName, 'password': password}),
    );
    final data = await _handleResponse(response);
    final String token = data['access_token'] as String;
    await saveToken(token);
    return (token: token, user: User.fromJson(data['user']));
  }

  Future<({String token, User user})> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = await _handleResponse(response);
    final String token = data['access_token'] as String;
    await saveToken(token);
    return (token: token, user: User.fromJson(data['user']));
  }

  // --- Gratitude ---

  Future<List<GratitudeEntry>> getMyGratitudes({int limit = 30, int offset = 0}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/gratitudes?limit=$limit&offset=$offset'),
      headers: _headers,
    );
    final list = jsonDecode(response.body) as List;
    return list.map((e) => GratitudeEntry.fromJson(e)).toList();
  }

  Future<GratitudeEntry> createGratitude(String title, String? description, {String? entryDate}) async {
    final body = <String, dynamic>{'title': title, 'description': description};
    if (entryDate != null) body['entry_date'] = entryDate;
    final response = await http.post(
      Uri.parse('$_baseUrl/gratitudes'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final data = await _handleResponse(response);
    return GratitudeEntry.fromJson(data);
  }

  Future<void> deleteGratitude(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/gratitudes/$id'),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      await _handleResponse(response);
    }
  }

  // --- Feed ---

  Future<List<GratitudeEntry>> getFeed({int limit = 30, int offset = 0}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/gratitudes/feed?limit=$limit&offset=$offset'),
      headers: _headers,
    );
    final list = jsonDecode(response.body) as List;
    return list.map((e) => GratitudeEntry.fromJson(e)).toList();
  }

  // --- Users ---

  Future<User> getMe() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return User.fromJson(data);
  }

  Future<List<User>> getUsers() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users'),
      headers: _headers,
    );
    final list = jsonDecode(response.body) as List;
    return list.map((e) => User.fromJson(e)).toList();
  }

  Future<List<GratitudeEntry>> getUserGratitudes(String userId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userId/gratitudes'),
      headers: _headers,
    );
    final list = jsonDecode(response.body) as List;
    return list.map((e) => GratitudeEntry.fromJson(e)).toList();
  }

  // --- Streaks ---

  Future<Streak> getMyStreak() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/streaks/me'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return Streak.fromJson(data);
  }
}
