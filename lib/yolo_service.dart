import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'api_key_service.dart';

class YoloDetection {
  final String label;
  final double confidence;
  final int? count;
  final Map<String, dynamic>? box;

  YoloDetection({
    required this.label,
    required this.confidence,
    this.count,
    this.box,
  });

  factory YoloDetection.fromMap(Map<String, dynamic> map) {
    final rawLabel = (map['label'] ?? map['name'] ?? '').toString();
    final confidenceValue = map['confidence'] ?? map['score'] ?? 0.0;

    return YoloDetection(
      label: rawLabel,
      confidence: confidenceValue is num ? confidenceValue.toDouble() : 0.0,
      count: map['count'] is num ? (map['count'] as num).toInt() : null,
      box: map['box'] as Map<String, dynamic>?,
    );
  }
}

class YoloService {
  YoloService._();
  static final YoloService instance = YoloService._();

  static const String _defaultEndpoint =
      'https://serverless.roboflow.com/exp777/yolov8/3';
  static const double _defaultMinConfidence = 0.35;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  bool get isConfigured => _defaultEndpoint.isNotEmpty;

  Future<String?> _resolveApiKey() async {
    final customKey = await ApiKeyService.instance.getKey(ManagedApiKey.yolo);
    if (ApiKeyService.isUsableKey(customKey)) {
      return customKey;
    }
    return null;
  }

  Future<String> _resolveEndpoint() async {
    final customEndpoint = await ApiKeyService.instance.getConfig(
      ManagedApiConfig.yoloEndpoint,
    );
    if (customEndpoint.trim().isNotEmpty) {
      return customEndpoint.trim();
    }
    return _defaultEndpoint;
  }

  Future<double> _resolveMinConfidence() async {
    final configValue = await ApiKeyService.instance.getConfig(
      ManagedApiConfig.yoloMinConfidence,
    );
    final parsed = double.tryParse(configValue.trim());
    if (parsed == null || parsed < 0 || parsed > 1) {
      return _defaultMinConfidence;
    }
    return parsed;
  }

  Future<List<YoloDetection>> detectFoods(File imageFile) async {
    final endpoint = await _resolveEndpoint();
    final minConfidence = await _resolveMinConfidence();
    if (endpoint.isEmpty) {
      throw StateError('YOLO 服務尚未設定');
    }
    final apiKey = await _resolveApiKey();
    if (apiKey == null) {
      throw StateError('YOLO API Key 未設定');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: p.basename(imageFile.path),
      ),
    });

    try {
      final response = await _dio.post<Object?>(
        endpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

      final body = response.data;
      List<dynamic>? detections;

      if (body is Map<String, dynamic>) {
        if (body['detections'] is List) {
          detections = body['detections'] as List;
        } else if (body['results'] is List) {
          detections = body['results'] as List;
        }
      } else if (body is List) {
        detections = body;
      }

      if (detections == null) return [];

      return detections
          .map((raw) => YoloDetection.fromMap(raw as Map<String, dynamic>))
          .where((detection) => detection.confidence >= minConfidence)
          .toList();
    } on DioException catch (e) {
      debugPrint('YOLO API 錯誤: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('YOLO API 未知錯誤: $e');
      rethrow;
    }
  }
}
