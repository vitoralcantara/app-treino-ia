import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsState {
  final String? geminiApiKey;
  final bool autoSyncEnabled;
  final bool syncOnWifiOnly;
  final int syncIntervalMinutes;
  final bool autoSelectNextSet;

  SettingsState({
    this.geminiApiKey,
    this.autoSyncEnabled = true,
    this.syncOnWifiOnly = false,
    this.syncIntervalMinutes = 30,
    this.autoSelectNextSet = false,
  });

  SettingsState copyWith({
    String? geminiApiKey,
    bool? autoSyncEnabled,
    bool? syncOnWifiOnly,
    int? syncIntervalMinutes,
    bool? autoSelectNextSet,
  }) {
    return SettingsState(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      autoSelectNextSet: autoSelectNextSet ?? this.autoSelectNextSet,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  // Apenas para dados sensíveis (API Key)
  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(),
  );
  
  static const _apiKeyKey = 'gemini_api_key';
  
  // Para configurações gerais do app
  static const _autoSyncEnabledKey = 'auto_sync_enabled';
  static const _syncOnWifiOnlyKey = 'sync_on_wifi_only';
  static const _syncIntervalMinutesKey = 'sync_interval_minutes';
  static const _autoSelectNextSetKey = 'auto_select_next_set';

  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Tenta ler a API Key do armazenamento seguro
    String? apiKey;
    try {
      apiKey = await _secureStorage.read(key: _apiKeyKey);
    } catch (e) {
      // Falha silenciosa no Keychain (comum em simuladores iOS sem Keychain Sharing)
      apiKey = null;
    }

    state = SettingsState(
      geminiApiKey: apiKey,
      autoSyncEnabled: prefs.getBool(_autoSyncEnabledKey) ?? true,
      syncOnWifiOnly: prefs.getBool(_selectedSyncOnWifiOnlyKey) ?? prefs.getBool(_syncOnWifiOnlyKey) ?? false,
      syncIntervalMinutes: prefs.getInt(_syncIntervalMinutesKey) ?? 30,
      autoSelectNextSet: prefs.getBool(_autoSelectNextSetKey) ?? false,
    );
  }

  // Chave interna para migração se necessário
  static const _selectedSyncOnWifiOnlyKey = 'sync_on_wifi_only_pref';

  Future<void> saveApiKey(String apiKey) async {
    try {
      await _secureStorage.write(key: _apiKeyKey, value: apiKey);
      state = state.copyWith(geminiApiKey: apiKey);
    } catch (e) {
      // Se falhar o armazenamento seguro, mantemos em memória mas avisamos
      state = state.copyWith(geminiApiKey: apiKey);
      throw Exception('Erro ao salvar no Keychain: $e');
    }
  }

  Future<void> clearApiKey() async {
    try {
      await _secureStorage.delete(key: _apiKeyKey);
    } catch (_) {}
    state = state.copyWith(geminiApiKey: null);
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncEnabledKey, enabled);
    state = state.copyWith(autoSyncEnabled: enabled);
  }

  Future<void> setSyncOnWifiOnly(bool wifiOnly) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncOnWifiOnlyKey, wifiOnly);
    state = state.copyWith(syncOnWifiOnly: wifiOnly);
  }

  Future<void> setSyncIntervalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncIntervalMinutesKey, minutes);
    state = state.copyWith(syncIntervalMinutes: minutes);
  }

  Future<void> setAutoSelectNextSet(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSelectNextSetKey, enabled);
    state = state.copyWith(autoSelectNextSet: enabled);
  }
}
