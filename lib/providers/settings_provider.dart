import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsState {
  final String? geminiApiKey;

  SettingsState({this.geminiApiKey});

  SettingsState copyWith({String? geminiApiKey}) {
    return SettingsState(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _storage = FlutterSecureStorage();
  static const _apiKeyKey = 'gemini_api_key';

  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState();
  }

  Future<void> _loadSettings() async {
    final apiKey = await _storage.read(key: _apiKeyKey);
    state = state.copyWith(geminiApiKey: apiKey);
  }

  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
    state = state.copyWith(geminiApiKey: apiKey);
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _apiKeyKey);
    state = SettingsState(geminiApiKey: null);
  }
}
