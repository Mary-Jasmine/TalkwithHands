import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/admin_analytics.dart';
import 'api_config.dart';

class AdminAnalyticsService {
  static const _jwtKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

  final Dio _dio;

  AdminAnalyticsService._(this._dio);

  factory AdminAnalyticsService() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.requireBaseUrl(),
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _jwtKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    return AdminAnalyticsService._(dio);
  }

  Future<AdminAnalytics> getAnalytics() async {
    final res = await _dio.get('/admin/analytics');
    return AdminAnalytics.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}
