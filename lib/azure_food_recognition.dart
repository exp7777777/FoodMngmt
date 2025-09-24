import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AzureFoodRecognition {
  // 強烈建議改為以 --dart-define 或後端代理方式提供機密
  static const String endpoint = 'ENDPOINT';
  static const String apiKey = 'APIKEY';
  // 預設為你的 Custom Vision 專案與發佈名稱（分類模型）
  static const String defaultProjectId = 'ProjectId';
  static const String defaultPublishName = 'Iteration 1';

  final Dio _dio = Dio();

  // 使用 Custom Vision Prediction API（請填入你的 projectId 與 publishName）
  Future<List<Map<String, dynamic>>> predict(
    File imageFile, {
    String projectId = defaultProjectId,
    String publishName = defaultPublishName,
    bool detect = false,
  }) async {
    final base =
        endpoint.endsWith('/')
            ? endpoint.substring(0, endpoint.length - 1)
            : endpoint;
    final path =
        detect
            ? '/customvision/v3.0/Prediction/$projectId/detect/iterations/$publishName/image'
            : '/customvision/v3.0/Prediction/$projectId/classify/iterations/$publishName/image';

    try {
      final resp = await _dio.post(
        '$base$path',
        data: await imageFile.readAsBytes(),
        options: Options(
          headers: {
            'Prediction-Key': apiKey,
            'Content-Type': 'application/octet-stream',
          },
          validateStatus: (_) => true,
        ),
      );
      if (resp.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            '[AzurePredict] HTTP ${resp.statusCode} body=${resp.data}',
          );
        }
        throw DioException.badResponse(
          statusCode: resp.statusCode ?? 500,
          requestOptions: resp.requestOptions,
          response: resp,
        );
      }
      final preds = (resp.data['predictions'] as List?) ?? [];
      if (kDebugMode) {
        debugPrint('[AzurePredict] success count=${preds.length}');
      }
      return preds.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[AzurePredict] DioException: status=${e.response?.statusCode} data=${e.response?.data} message=${e.message}',
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AzurePredict] Unknown error: $e');
      }
      rethrow;
    }
  }
}
