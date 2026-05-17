import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const String offlineMessage =
      "You're offline right now. Please check your internet connection and try again.";
  static const String timeoutMessage =
      'The server is taking too long to respond. Please try again later.';
  static const String invalidResponseMessage =
      'We received an unexpected response from the server. Please try again later.';
  static const String genericFailureMessage =
      'Something went wrong. Please try again later.';

  static String get baseUrl => _normalizeBaseUrl(dotenv.env['BASE_URL']);

  static Uri uri(String path, {Map<String, dynamic>? queryParameters}) {
    final baseUri = Uri.parse(baseUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;

    final normalizedQueryParameters = queryParameters?.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    return baseUri.replace(
      path: '$basePath/$normalizedPath',
      queryParameters: normalizedQueryParameters?.isEmpty ?? true
          ? null
          : normalizedQueryParameters,
    );
  }

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) {
    return _send(() => http.get(uri, headers: headers), timeout: timeout);
  }

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = _defaultTimeout,
  }) {
    return _send(
      () => http.post(uri, headers: headers, body: body, encoding: encoding),
      timeout: timeout,
    );
  }

  static Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = _defaultTimeout,
  }) {
    return _send(
      () => http.put(uri, headers: headers, body: body, encoding: encoding),
      timeout: timeout,
    );
  }

  static Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = _defaultTimeout,
  }) {
    return _send(
      () => http.patch(uri, headers: headers, body: body, encoding: encoding),
      timeout: timeout,
    );
  }

  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = _defaultTimeout,
  }) {
    return _send(
      () => http.delete(uri, headers: headers, body: body, encoding: encoding),
      timeout: timeout,
    );
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(timeoutMessage);
    } on http.ClientException catch (error) {
      if (isConnectivityIssue(error.message)) {
        throw const ApiException(offlineMessage);
      }
      throw const ApiException(genericFailureMessage);
    } catch (error) {
      if (isConnectivityIssue(error.toString())) {
        throw const ApiException(offlineMessage);
      }
      rethrow;
    }
  }

  static Map<String, dynamic> decodeMap(
    http.Response response, {
    String fallbackMessage = invalidResponseMessage,
  }) {
    final decoded = decodeBody(response, fallbackMessage: fallbackMessage);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw ApiException(fallbackMessage, statusCode: response.statusCode);
  }

  static dynamic decodeBody(
    http.Response response, {
    String fallbackMessage = invalidResponseMessage,
  }) {
    final body = response.body.trim();

    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      throw ApiException(
        _looksLikeHtml(body) ? invalidResponseMessage : fallbackMessage,
        statusCode: response.statusCode,
      );
    }
  }

  static String errorMessage(
    http.Response response, {
    required String fallbackMessage,
  }) {
    try {
      final decoded = decodeBody(response, fallbackMessage: fallbackMessage);

      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } on ApiException catch (_) {
      return fallbackMessage;
    }

    return fallbackMessage;
  }

  static String _normalizeBaseUrl(String? rawUrl) {
    var value = (rawUrl ?? '').trim();

    if (value.isEmpty) {
      throw const ApiException('BASE_URL is missing from assets/.env');
    }

    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    if (!value.endsWith('/api')) {
      value = '$value/api';
    }

    return value;
  }

  static bool _looksLikeHtml(String body) {
    final trimmed = body.trimLeft().toLowerCase();
    return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
  }

  static bool isConnectivityIssue(String message) {
    final normalized = message.toLowerCase();
    const connectivityHints = [
      'failed host lookup',
      'connection refused',
      'network is unreachable',
      'software caused connection abort',
      'connection reset',
      'name or service not known',
      'nodename nor servname provided',
      'no address associated with hostname',
      'socketexception',
      'xmlhttprequest error',
      'failed to fetch',
      'network request failed',
      'offline',
    ];

    return connectivityHints.any(normalized.contains);
  }
}
