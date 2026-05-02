import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/secure_storage.dart';

/// Dio configurado com interceptor de Authorization + refresh token.
///
/// O refresh tem proteção anti-stampede: se vier vários 401 ao mesmo tempo,
/// só uma requisição renova; as demais aguardam.
class ApiClient {
  ApiClient({required this.dio, required this.tokens});

  final Dio dio;
  final TokenStore tokens;

  static ApiClient build(TokenStore tokens) {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.httpTimeout,
      receiveTimeout: AppConfig.httpTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    Completer<String?>? refreshing;

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokens.accessToken;
        if (token != null && options.headers['Authorization'] == null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) async {
        final isUnauth = e.response?.statusCode == 401;
        final isRefreshCall = e.requestOptions.path.contains('/auth/refresh');
        if (!isUnauth || isRefreshCall) return handler.next(e);

        try {
          // Se já tem um refresh em curso, aguarda
          if (refreshing != null) {
            final newToken = await refreshing!.future;
            if (newToken == null) return handler.next(e);
            final retry = await _retryWith(dio, e.requestOptions, newToken);
            return handler.resolve(retry);
          }

          refreshing = Completer<String?>();
          final refresh = await tokens.refreshToken;
          if (refresh == null) {
            refreshing!.complete(null);
            refreshing = null;
            return handler.next(e);
          }

          final resp = await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
              .post('/auth/refresh', data: {'refresh_token': refresh});
          final access = resp.data['access_token'] as String;
          final newRefresh =
              (resp.data['refresh_token'] as String?) ?? refresh;
          await tokens.saveTokens(access, newRefresh);

          refreshing!.complete(access);
          refreshing = null;

          final retry = await _retryWith(dio, e.requestOptions, access);
          return handler.resolve(retry);
        } catch (err) {
          refreshing?.complete(null);
          refreshing = null;
          await tokens.clear();
          return handler.next(e);
        }
      },
    ));

    return ApiClient(dio: dio, tokens: tokens);
  }

  static Future<Response<dynamic>> _retryWith(
    Dio dio,
    RequestOptions req,
    String token,
  ) {
    final headers = Map<String, dynamic>.from(req.headers)
      ..['Authorization'] = 'Bearer $token';
    return dio.request<dynamic>(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: Options(method: req.method, headers: headers),
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  return ApiClient.build(tokens);
});
