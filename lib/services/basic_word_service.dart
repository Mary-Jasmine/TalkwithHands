import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

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
    try {
      final res = await _dio.get('/basic-words');
      final data = res.data;
      if (data is! List) {
        throw Exception('Invalid basic words response from server.');
      }
      if (_containsGoogleDriveUrl(data)) {
        return _loadBundledBasicWords();
      }
      return _parseAndSort(data);
    } catch (_) {
      return _loadBundledBasicWords();
    }
  }

  Future<List<BasicWord>> _loadBundledBasicWords() async {
    final raw = await rootBundle.loadString('backend/data/basic-words.json');
    final data = jsonDecode(raw);
    if (data is! List) {
      throw Exception('Invalid bundled basic words data.');
    }
    return _parseAndSort(data);
  }

  List<BasicWord> _parseAndSort(List<dynamic> data) {
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

  bool _containsGoogleDriveUrl(List<dynamic> data) {
    return data.any((item) {
      if (item is Map) {
        final category = (item['category'] ?? '').toString().toLowerCase();
        if (category == 'alphabet' ||
            category == 'number' ||
            category == 'numbers') {
          return false;
        }
      }

      final value = item.toString().toLowerCase();
      return value.contains('drive.google') ||
          value.contains('drive.usercontent.google') ||
          value.contains('docs.google');
    });
  }
}
