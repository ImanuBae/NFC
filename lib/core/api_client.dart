import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'server_connection.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status = 400, this.code});
  final String message;
  final int status;
  final String? code;
  @override
  String toString() => message;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.employeeId,
    this.mustChangePassword = false,
  });
  final String id;
  final String email;
  final String role;
  final String? employeeId;
  final bool mustChangePassword;
  factory AppUser.fromJson(Map<String, dynamic> row) => AppUser(
    id: row['id'] as String,
    email: row['email'] as String,
    role: row['role'] as String,
    employeeId: row['employee_id'] as String?,
    mustChangePassword: row['must_change_password'] as bool? ?? false,
  );
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(serverUrlProvider));
  ref.onDispose(client.close);
  return client;
});

class ApiClient {
  ApiClient(this.baseUrl, {http.Client? transport})
    : _http = transport ?? http.Client();
  final String baseUrl;
  final http.Client _http;
  final _authChanges = StreamController<AppUser?>.broadcast();
  Stream<AppUser?> get authChanges => _authChanges.stream;
  AppUser? currentUser;
  String? _token;
  Future<void>? _initializing;
  String get _sessionKey => 'attendance_api_session_v1:$baseUrl';

  Future<void> initialize() => _initializing ??= _restore();
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_sessionKey);
    if (_token == null) return;
    try {
      currentUser = AppUser.fromJson(
        Map<String, dynamic>.from(await request('GET', '/auth/me') as Map),
      );
    } on ApiException catch (e) {
      if (e.status == 401) {
        _token = null;
        await prefs.remove(_sessionKey);
      } else {
        rethrow;
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    final data = Map<String, dynamic>.from(
      await request(
        'POST',
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
      ) as Map,
    );
    _token = data['token'] as String;
    currentUser = AppUser.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
    _initializing = Future.value();
    await (await SharedPreferences.getInstance()).setString(
      _sessionKey,
      _token!,
    );
    _authChanges.add(currentUser);
  }

  Future<void> signOut() async {
    try {
      if (_token != null) await request('POST', '/auth/logout', body: {});
    } finally {
      _token = null;
      currentUser = null;
      await (await SharedPreferences.getInstance()).remove(_sessionKey);
      _authChanges.add(null);
    }
  }

  Future<AppUser?> me() async {
    if (currentUser == null) return null;
    try {
      currentUser = AppUser.fromJson(
        Map<String, dynamic>.from(await request('GET', '/auth/me') as Map),
      );
      return currentUser;
    } on ApiException catch (e) {
      if (e.status == 401) return null;
      rethrow;
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String?>? query,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api$path')
        .replace(
          queryParameters: query == null
              ? null
              : {
                  for (final e in query.entries)
                    if (e.value != null) e.key: e.value!,
                },
        );
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) request.body = jsonEncode(body);
    late final http.Response response;
    try {
      response = await (() async => http.Response.fromStream(
        await _http.send(request),
      ))().timeout(timeout);
    } on http.ClientException {
      throw const ApiException(
        'Không kết nối được máy chủ. Hãy kiểm tra backend đang chạy và kết nối mạng.',
        status: 0,
        code: 'connection_failed',
      );
    } on TimeoutException {
      throw const ApiException(
        'Máy chủ phản hồi quá lâu. Hãy kiểm tra backend và thử lại.',
        status: 0,
        code: 'connection_timeout',
      );
    }
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'Máy chủ trả dữ liệu không hợp lệ.',
        status: response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        data is Map
            ? '${data['error'] ?? 'Yêu cầu thất bại.'}'
            : 'Yêu cầu thất bại.',
        status: response.statusCode,
      );
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, String?>? query,
  }) async => (await request('GET', path, query: query) as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  void close() {
    _http.close();
    _authChanges.close();
  }
}
