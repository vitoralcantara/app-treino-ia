import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  static const _storage = FlutterSecureStorage();
  static const _apiKeyKey = 'gemini_api_key';
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
    final apiKey = await _storage.read(key: _apiKeyKey);
    final autoSyncEnabled = await _storage.read(key: _autoSyncEnabledKey);
    final syncOnWifiOnly = await _storage.read(key: _syncOnWifiOnlyKey);
    final syncIntervalMinutes = await _storage.read(key: _syncIntervalMinutesKey);
    final autoSelectNextSet = await _storage.read(key: _autoSelectNextSetKey);

    state = SettingsState(
      geminiApiKey: apiKey,
      autoSyncEnabled: autoSyncEnabled == null ? true : autoSyncEnabled == 'true',
      syncOnWifiOnly: syncOnWifiOnly == 'true',
      syncIntervalMinutes: syncIntervalMinutes != null 
          ? int.tryParse(syncIntervalMinutes) ?? 30 
          : 30,
      autoSelectNextSet: autoSelectNextSet == 'true',
    );
  }

  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
    state = state.copyWith(geminiApiKey: apiKey);
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: _apiKeyKey);
    state = SettingsState(geminiApiKey: null);
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    await _storage.write(key: _autoSyncEnabledKey, value: enabled.toString());
    state = state.copyWith(autoSyncEnabled: enabled);
  }

  Future<void> setSyncOnWifiOnly(bool wifiOnly) async {
    await _storage.write(key: _syncOnWifiOnlyKey, value: wifiOnly.toString());
    state = state.copyWith(syncOnWifiOnly: wifiOnly);
  }

  Future<void> setSyncIntervalMinutes(int minutes) async {
    await _storage.write(key: _syncIntervalMinutesKey, value: minutes.toString());
    state = state.copyWith(syncIntervalMinutes: minutes);
  }

  Future<void> setAutoSelectNextSet(bool enabled) async {
    await _storage.write(key: _autoSelectNextSetKey, value: enabled.toString());
    state = state.copyWith(autoSelectNextSet: enabled);
  }
}
