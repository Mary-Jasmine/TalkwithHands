import 'package:dio/dio.dart';

import '../models/basic_word.dart';
import 'api_config.dart';

class BasicWordService {
  final Dio _dio;

  BasicWordService._(this._dio);

  factory BasicWordService() {
    final baseUrl = ApiConfig.requireBaseUrl();

    return BasicWordService._(
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

  Future<List<BasicWord>> listBasicWords() async {
    final res = await _dio.get('/basic-words');
    final data = res.data;
    if (data is! List) {
      throw Exception('Invalid basic words response from server.');
    }

    return data
        .whereType<Map>()
        .map((item) => BasicWord.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) {
        final categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) return categoryCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });
  }
}
