import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_key_service.dart';

class VoiceService {
  static VoiceService? _instance;
  static VoiceService get instance {
    _instance ??= VoiceService._();
    return _instance!;
  }

  VoiceService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  String _currentRecognizedText = ''; // 保存當前識別的文字

  Future<String?> _resolveApiKey() async {
    final customKey = await ApiKeyService.instance.getKey(ManagedApiKey.voice);
    if (ApiKeyService.isUsableKey(customKey)) {
      return customKey;
    }
    return null;
  }

  /// 初始化語音識別
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // 請求麥克風權限
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('麥克風權限被拒絕');
        return false;
      }

      // 初始化語音識別
      _isInitialized = await _speech.initialize(
        onError: (error) => debugPrint('語音識別錯誤: $error'),
        onStatus: (status) => debugPrint('語音識別狀態: $status'),
      );

      debugPrint('語音識別初始化: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      debugPrint('初始化語音識別失敗: $e');
      return false;
    }
  }

  /// 開始語音識別
  Future<String?> startListening({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    try {
      String recognizedText = '';

      await _speech.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords;
          debugPrint('識別的文字: $recognizedText');
        },
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
        localeId: 'zh_TW', // 使用繁體中文
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: false,
        ),
      );

      // 等待語音識別完成
      await Future.delayed(timeout + const Duration(seconds: 1));

      if (recognizedText.isNotEmpty) {
        debugPrint('最終識別文字: $recognizedText');
        return recognizedText;
      }

      return null;
    } catch (e) {
      debugPrint('語音識別失敗: $e');
      return null;
    }
  }

  /// 停止語音識別
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// 開始持續語音識別（無超時限制）
  Future<void> startContinuousListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('語音識別初始化失敗');
        return;
      }
    }

    try {
      _currentRecognizedText = ''; // 重置識別文字

      await _speech.listen(
        onResult: (result) {
          _currentRecognizedText = result.recognizedWords;
          debugPrint('即時識別文字: $_currentRecognizedText');
        },
        localeId: 'zh_TW', // 使用繁體中文
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          partialResults: true, // 啟用即時結果
          listenMode: stt.ListenMode.confirmation, // 持續監聽模式
        ),
      );

      debugPrint('開始持續語音識別');
    } catch (e) {
      debugPrint('開始語音識別失敗: $e');
      rethrow;
    }
  }

  /// 停止錄音並獲取結果
  Future<String?> stopAndGetResult() async {
    try {
      await _speech.stop();
      debugPrint('停止錄音，最終識別文字: $_currentRecognizedText');

      // 稍等一下確保識別完成
      await Future.delayed(const Duration(milliseconds: 500));

      final result =
          _currentRecognizedText.isNotEmpty ? _currentRecognizedText : null;

      _currentRecognizedText = ''; // 清空識別文字
      return result;
    } catch (e) {
      debugPrint('停止錄音失敗: $e');
      return null;
    }
  }

  /// 使用 Gemini API 解析語音內容
  Future<List<Map<String, String>>> parseVoiceInput(String voiceText) async {
    try {
      final apiKey = await _resolveApiKey();
      if (apiKey == null) {
        debugPrint('Voice API Key 未設定，略過語音 AI 解析');
        return [];
      }

      final prompt = '''
你是一個專業的購物清單助手。請從以下語音輸入中提取食材名稱和數量：

語音輸入：「$voiceText」

請仔細分析語音內容，提取所有提到的食材及其數量。

規則：
1. 識別所有提到的食材名稱
2. 提取對應的數量和單位（如果有）
3. 如果沒有明確提到數量，設為 "1個"
4. 支援多個食材（例如：「買雞蛋、牛奶和麵包」）
5. 支援數量描述（例如：「三瓶牛奶」、「一打雞蛋」、「兩斤豬肉」）

請用以下 JSON 格式回應，不要添加任何其他文字：
{
  "items": [
    {
      "name": "食材名稱",
      "amount": "數量單位"
    }
  ]
}

範例：
輸入：「我要買雞蛋、三瓶牛奶和兩斤豬肉」
輸出：
{
  "items": [
    {"name": "雞蛋", "amount": "1盒"},
    {"name": "牛奶", "amount": "3瓶"},
    {"name": "豬肉", "amount": "2斤"}
  ]
}
''';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.2,
            'topK': 20,
            'topP': 0.8,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Gemini API 回應: $data');

        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content'];
          if (content != null && content['parts'] != null) {
            final text = content['parts'][0]['text'];
            return _parseItemsFromJson(text);
          }
        }
      } else {
        debugPrint('Gemini API 請求失敗: ${response.statusCode}');
        debugPrint('回應內容: ${response.body}');
      }
    } catch (e) {
      debugPrint('解析語音內容失敗: $e');
    }

    return [];
  }

  /// 從 JSON 文字中解析食材清單
  List<Map<String, String>> _parseItemsFromJson(String text) {
    try {
      // 移除可能的 markdown 標記
      String cleanText = text.trim();
      if (cleanText.startsWith('```json')) {
        cleanText = cleanText.substring(7);
      }
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.substring(3);
      }
      if (cleanText.endsWith('```')) {
        cleanText = cleanText.substring(0, cleanText.length - 3);
      }
      cleanText = cleanText.trim();

      final data = json.decode(cleanText);
      final items = data['items'] as List?;

      if (items != null) {
        return items
            .map(
              (item) => {
                'name': item['name']?.toString() ?? '',
                'amount': item['amount']?.toString() ?? '1個',
              },
            )
            .where((item) => item['name']!.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('解析 JSON 失敗: $e');
      debugPrint('文字內容: $text');
    }

    return [];
  }

  /// 檢查是否正在監聽
  bool get isListening => _speech.isListening;

  /// 檢查是否可用
  bool get isAvailable => _isInitialized;
}
