import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class HttpBuilder {
  String? _baseUrl;
  Duration _connectTimeout = const Duration(milliseconds: 15000);
  Duration _sendTimeout = const Duration(milliseconds: 15000);
  Duration _receiveTimeout = const Duration(milliseconds: 15000);
  final Map<String, dynamic> _headers = {};
  final List<Interceptor> _interceptors = [];
  bool Function(int? statusCode)? _validateStatus;
  int? _maxRedirects;
  bool _followRedirects = true;
  bool _persistentConnection = true;
  ResponseType _responseType = ResponseType.json;
  String? _proxy;
  bool _ignoreSsl = false;

  HttpBuilder();

  String? get getBaseUrl => _baseUrl;
  String? get getProxy => _proxy;
  bool get isIgnoreSsl => _ignoreSsl;

  HttpBuilder baseUrl(String url) {
    _baseUrl = url;
    return this;
  }

  HttpBuilder connectTimeout(Duration duration) {
    _connectTimeout = duration;
    return this;
  }

  HttpBuilder sendTimeout(Duration duration) {
    _sendTimeout = duration;
    return this;
  }

  HttpBuilder receiveTimeout(Duration duration) {
    _receiveTimeout = duration;
    return this;
  }

  HttpBuilder header(String key, dynamic value) {
    _headers[key] = value;
    return this;
  }

  HttpBuilder headers(Map<String, dynamic> map) {
    _headers.addAll(map);
    return this;
  }

  HttpBuilder addInterceptor(Interceptor interceptor) {
    _interceptors.add(interceptor);
    return this;
  }

  HttpBuilder validateStatus(bool Function(int? statusCode) fn) {
    _validateStatus = fn;
    return this;
  }

  HttpBuilder followRedirects(bool enable) {
    _followRedirects = enable;
    return this;
  }

  HttpBuilder maxRedirects(int count) {
    _maxRedirects = count;
    return this;
  }

  HttpBuilder persistentConnection(bool enable) {
    _persistentConnection = enable;
    return this;
  }

  HttpBuilder responseType(ResponseType type) {
    _responseType = type;
    return this;
  }

  HttpBuilder proxy(String? proxyAddr) {
    _proxy = proxyAddr;
    return this;
  }

  HttpBuilder ignoreSsl(bool ignore) {
    _ignoreSsl = ignore;
    return this;
  }

  HttpBuilder clone() {
    final copied = HttpBuilder()
      .._baseUrl = _baseUrl
      .._connectTimeout = _connectTimeout
      .._sendTimeout = _sendTimeout
      .._receiveTimeout = _receiveTimeout
      .._headers.addAll(_headers)
      .._interceptors.addAll(_interceptors)
      .._validateStatus = _validateStatus
      .._maxRedirects = _maxRedirects
      .._followRedirects = _followRedirects
      .._persistentConnection = _persistentConnection
      .._responseType = _responseType
      .._proxy = _proxy
      .._ignoreSsl = _ignoreSsl;
    return copied;
  }

  Dio build() {
    final options = BaseOptions(
      baseUrl: _baseUrl ?? "",
      connectTimeout: _connectTimeout,
      sendTimeout: _sendTimeout,
      receiveTimeout: _receiveTimeout,
      headers: Map<String, dynamic>.from(_headers),
      validateStatus: _validateStatus,
      followRedirects: _followRedirects,
      maxRedirects: _maxRedirects,
      persistentConnection: _persistentConnection,
      responseType: _responseType,
    );
    final dio = Dio(options);

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        if (_ignoreSsl) {
          client.badCertificateCallback = (cert, host, port) => true;
        }
        if (_proxy != null && _proxy!.isNotEmpty) {
          final parts = _proxy!.split(":");
          if (parts.length == 2) {
            client.findProxy = (uri) {
              return "PROXY ${parts[0]}:${parts[1]}";
            };
          }
        }
        return client;
      },
    );

    dio.interceptors.addAll(_interceptors);
    return dio;
  }
}
