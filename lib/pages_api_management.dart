import 'package:flutter/material.dart';

import 'api_key_service.dart';

class ApiManagementPage extends StatefulWidget {
  const ApiManagementPage({super.key});

  @override
  State<ApiManagementPage> createState() => _ApiManagementPageState();
}

class _ApiManagementPageState extends State<ApiManagementPage> {
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _yoloController = TextEditingController();
  final TextEditingController _voiceController = TextEditingController();
  final TextEditingController _googlePlacesController = TextEditingController();
  final TextEditingController _yoloEndpointController = TextEditingController();
  final TextEditingController _yoloMinConfController = TextEditingController();

  bool _geminiObscure = true;
  bool _yoloObscure = true;
  bool _voiceObscure = true;
  bool _googlePlacesObscure = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _yoloController.dispose();
    _voiceController.dispose();
    _googlePlacesController.dispose();
    _yoloEndpointController.dispose();
    _yoloMinConfController.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    final keys = await ApiKeyService.instance.getAllKeys();
    final configs = await ApiKeyService.instance.getAllConfigs();
    _geminiController.text = keys[ManagedApiKey.gemini] ?? '';
    _yoloController.text = keys[ManagedApiKey.yolo] ?? '';
    _voiceController.text = keys[ManagedApiKey.voice] ?? '';
    _googlePlacesController.text =
        configs[ManagedApiConfig.googlePlacesKey] ?? '';
    _yoloEndpointController.text = configs[ManagedApiConfig.yoloEndpoint] ?? '';
    _yoloMinConfController.text =
        configs[ManagedApiConfig.yoloMinConfidence] ?? '';
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveKeys() async {
    setState(() => _isSaving = true);
    await ApiKeyService.instance.setKey(
      ManagedApiKey.gemini,
      _geminiController.text,
    );
    await ApiKeyService.instance.setKey(ManagedApiKey.yolo, _yoloController.text);
    await ApiKeyService.instance.setKey(
      ManagedApiKey.voice,
      _voiceController.text,
    );
    await ApiKeyService.instance.setConfig(
      ManagedApiConfig.googlePlacesKey,
      _googlePlacesController.text,
    );
    await ApiKeyService.instance.setConfig(
      ManagedApiConfig.yoloEndpoint,
      _yoloEndpointController.text,
    );
    await ApiKeyService.instance.setConfig(
      ManagedApiConfig.yoloMinConfidence,
      _yoloMinConfController.text,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API Key 已儲存')));
  }

  Future<void> _clearKey(ManagedApiKey type) async {
    switch (type) {
      case ManagedApiKey.gemini:
        _geminiController.clear();
        break;
      case ManagedApiKey.yolo:
        _yoloController.clear();
        break;
      case ManagedApiKey.voice:
        _voiceController.clear();
        break;
    }
    await ApiKeyService.instance.setKey(type, '');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除該 API Key')));
  }

  Future<void> _clearConfig(ManagedApiConfig type) async {
    switch (type) {
      case ManagedApiConfig.googlePlacesKey:
        _googlePlacesController.clear();
        break;
      case ManagedApiConfig.yoloEndpoint:
        _yoloEndpointController.clear();
        break;
      case ManagedApiConfig.yoloMinConfidence:
        _yoloMinConfController.clear();
        break;
    }
    await ApiKeyService.instance.setConfig(type, '');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除該 API 設定')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API 管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '可在這裡管理所有 API Key 與 API 設定。\n若欄位留空，會使用預設值或停用該功能，不影響一般本機資料使用。',
                  ),
                  const SizedBox(height: 16),
                  _buildKeyCard(
                    title: 'Gemini API Key',
                    controller: _geminiController,
                    obscureText: _geminiObscure,
                    onToggleObscure: () {
                      setState(() => _geminiObscure = !_geminiObscure);
                    },
                    onClear: () => _clearKey(ManagedApiKey.gemini),
                  ),
                  const SizedBox(height: 12),
                  _buildKeyCard(
                    title: 'YOLO API Key',
                    controller: _yoloController,
                    obscureText: _yoloObscure,
                    onToggleObscure: () {
                      setState(() => _yoloObscure = !_yoloObscure);
                    },
                    onClear: () => _clearKey(ManagedApiKey.yolo),
                  ),
                  const SizedBox(height: 12),
                  _buildKeyCard(
                    title: 'Voice API Key',
                    controller: _voiceController,
                    obscureText: _voiceObscure,
                    onToggleObscure: () {
                      setState(() => _voiceObscure = !_voiceObscure);
                    },
                    onClear: () => _clearKey(ManagedApiKey.voice),
                  ),
                  const SizedBox(height: 12),
                  _buildKeyCard(
                    title: 'Google Places API Key',
                    controller: _googlePlacesController,
                    obscureText: _googlePlacesObscure,
                    onToggleObscure: () {
                      setState(
                        () => _googlePlacesObscure = !_googlePlacesObscure,
                      );
                    },
                    onClear: () =>
                        _clearConfig(ManagedApiConfig.googlePlacesKey),
                  ),
                  const SizedBox(height: 12),
                  _buildTextCard(
                    title: 'YOLO Endpoint',
                    controller: _yoloEndpointController,
                    hintText: '例如：https://serverless.roboflow.com/exp777/yolov8/3',
                    onClear: () => _clearConfig(ManagedApiConfig.yoloEndpoint),
                  ),
                  const SizedBox(height: 12),
                  _buildTextCard(
                    title: 'YOLO 最低信心值',
                    controller: _yoloMinConfController,
                    hintText: '例如：0.35',
                    onClear: () =>
                        _clearConfig(ManagedApiConfig.yoloMinConfidence),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveKeys,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? '儲存中...' : '儲存設定'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKeyCard({
    required String title,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    required VoidCallback onClear,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: '請輸入 $title',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                      ),
                      tooltip: obscureText ? '顯示' : '隱藏',
                    ),
                    IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.clear),
                      tooltip: '清除',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextCard({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onClear,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                  tooltip: '清除',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
