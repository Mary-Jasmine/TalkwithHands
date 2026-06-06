import 'package:dio/dio.dart';

import '../models/panorama_scene.dart';
import 'api_config.dart';

class PanoramaService {
  final Dio _dio;

  PanoramaService._(this._dio);

  factory PanoramaService() {
    final baseUrl = ApiConfig.requireBaseUrl();

    return PanoramaService._(
      Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Content-Type': 'application/json'},
        ),
      ),
    );
  }

  Future<List<PanoramaScene>> listPanoramaScenes() async {
    final res = await _dio.get('/panorama-scenes');
    final data = res.data;
    if (data is! List) {
      throw Exception('Invalid panorama response from server.');
    }

    return data
        .whereType<Map>()
        .map((item) => PanoramaScene.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}
