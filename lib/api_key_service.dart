import 'local_database.dart';

enum ManagedApiKey { gemini, yolo, voice }
enum ManagedApiConfig { googlePlacesKey, yoloEndpoint, yoloMinConfidence }

class ApiKeyService {
  ApiKeyService._();

  static final ApiKeyService instance = ApiKeyService._();

  static const String _geminiKeyType = 'gemini';
  static const String _yoloKeyType = 'yolo';
  static const String _voiceKeyType = 'voice';
  static const String _googlePlacesKeyType = 'google_places';
  static const String _yoloEndpointType = 'yolo_endpoint';
  static const String _yoloMinConfidenceType = 'yolo_min_confidence';

  String _toKeyType(ManagedApiKey keyType) {
    switch (keyType) {
      case ManagedApiKey.gemini:
        return _geminiKeyType;
      case ManagedApiKey.yolo:
        return _yoloKeyType;
      case ManagedApiKey.voice:
        return _voiceKeyType;
    }
  }

  String _toConfigType(ManagedApiConfig configType) {
    switch (configType) {
      case ManagedApiConfig.googlePlacesKey:
        return _googlePlacesKeyType;
      case ManagedApiConfig.yoloEndpoint:
        return _yoloEndpointType;
      case ManagedApiConfig.yoloMinConfidence:
        return _yoloMinConfidenceType;
    }
  }

  static bool isUsableKey(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return trimmed != 'YOUR API KEY';
  }

  Future<String> getKey(ManagedApiKey keyType) async {
    return _getValue(_toKeyType(keyType));
  }

  Future<String> getConfig(ManagedApiConfig configType) async {
    return _getValue(_toConfigType(configType));
  }

  Future<String> _getValue(String keyType) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'api_keys',
      columns: ['api_key'],
      where: 'key_type = ?',
      whereArgs: [keyType],
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return (rows.first['api_key'] as String? ?? '').trim();
  }

  Future<void> setKey(ManagedApiKey keyType, String value) async {
    await _setValue(_toKeyType(keyType), value);
  }

  Future<void> setConfig(ManagedApiConfig configType, String value) async {
    await _setValue(_toConfigType(configType), value);
  }

  Future<void> _setValue(String keyType, String value) async {
    final db = await LocalDatabase.instance.database;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await db.delete('api_keys', where: 'key_type = ?', whereArgs: [keyType]);
      return;
    }
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO api_keys (key_type, api_key, updated_at)
      VALUES (?, ?, ?)
      ''',
      [keyType, trimmed, DateTime.now().toIso8601String()],
    );
  }

  Future<Map<ManagedApiKey, String>> getAllKeys() async {
    return {
      ManagedApiKey.gemini: await getKey(ManagedApiKey.gemini),
      ManagedApiKey.yolo: await getKey(ManagedApiKey.yolo),
      ManagedApiKey.voice: await getKey(ManagedApiKey.voice),
    };
  }

  Future<Map<ManagedApiConfig, String>> getAllConfigs() async {
    return {
      ManagedApiConfig.googlePlacesKey: await getConfig(
        ManagedApiConfig.googlePlacesKey,
      ),
      ManagedApiConfig.yoloEndpoint: await getConfig(
        ManagedApiConfig.yoloEndpoint,
      ),
      ManagedApiConfig.yoloMinConfidence: await getConfig(
        ManagedApiConfig.yoloMinConfidence,
      ),
    };
  }
}
