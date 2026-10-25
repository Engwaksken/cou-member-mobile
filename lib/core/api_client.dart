import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Error returned by the member API, with a message that is safe to show to the member.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode = 0});

  final String message;
  final int statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin client for the church member API (`api/member/?action=...`).
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Bearer token for signed-in requests.
  String? token;

  /// Called when the server rejects the token, so the app can return to sign-in.
  void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> get(String action, [Map<String, String> params = const {}]) {
    return _send(() => _http.get(_uri(action, params), headers: _headers()));
  }

  Future<Map<String, dynamic>> post(String action, Map<String, dynamic> body) {
    return _send(() => _http.post(_uri(action), headers: _headers(json: true), body: jsonEncode(body)));
  }

  Uri _uri(String action, [Map<String, String> params = const {}]) {
    final base = Uri.parse(baseUrl);
    return base.replace(queryParameters: {...base.queryParameters, 'action': action, ...params});
  }

  Map<String, String> _headers({bool json = false}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        // Some shared hosts strip Authorization; the API also accepts this header.
        'X-Auth-Token': ?token,
      };

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('The church server took too long to respond. Please try again.');
    } on SocketException {
      throw ApiException('No internet connection. Check your connection and try again.');
    } on HandshakeException {
      throw ApiException("Could not make a secure connection to the church server. Check the phone's date and time.");
    } on http.ClientException {
      throw ApiException('Could not reach the church server. Please try again.');
    } on IOException {
      throw ApiException('Could not reach the church server. Please try again.');
    }

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      data = null;
    }

    if (response.statusCode == 200 && data != null && data['success'] == true) return data;

    final message = (data?['message'] as String?) ??
        (response.statusCode == 404
            ? 'The church server does not have the member app service yet (error 404).'
            : 'Something went wrong (error ${response.statusCode}).');
    if (response.statusCode == 401 && token != null) onUnauthorized?.call();
    throw ApiException(message, statusCode: response.statusCode);
  }
}
