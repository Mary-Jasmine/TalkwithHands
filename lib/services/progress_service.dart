import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_progress.dart';
import 'api_config.dart';

class ProgressService {
  static const _jwtKey = 'auth_jwt';
  static const _storage = FlutterSecureStorage();

  final Dio _dio;

  ProgressService._(this._dio);

  factory ProgressService() {
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

    return ProgressService._(dio);
  }

  Future<UserProgress> getProgress() async {
    try {
      final res = await _dio.get('/progress');
      return UserProgress.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final res = await _dio.get('/auth/me');
        return UserProgress.fromUserProfileJson(
          Map<String, dynamic>.from(res.data as Map),
        );
      }

      dev.log(
        'ProgressService.getProgress failed',
        name: 'ProgressService',
        error: e,
      );
      dev.log(
        'Status: ${e.response?.statusCode}  Body: \${e.response?.data}',
        name: 'ProgressService',
      );
      rethrow;
    } catch (e) {
      dev.log(
        'ProgressService.getProgress unexpected error',
        name: 'ProgressService',
        error: e,
      );
      rethrow;
    }
  }

  Future<UserProgress> recordActivity({
    required String category,
    String? itemKey,
    int secondsSpent = 0,
    bool gameCompleted = false,
    bool countEvent = true,
  }) async {
    final res = await _dio.post(
      '/progress/activity',
      data: {
        'category': category,
        if (itemKey != null) 'item_key': itemKey,
        'seconds_spent': secondsSpent,
        'game_completed': gameCompleted,
        'count_event': countEvent,
      },
    );
    return UserProgress.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}
