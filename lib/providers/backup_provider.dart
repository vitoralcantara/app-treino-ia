import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/google_drive_service.dart';
import 'settings_provider.dart';

class BackupState {
  final bool isConnecting;
  final bool isUploading;
  final bool isDownloading;
  final String? userEmail;
  final DateTime? lastBackupDate;
  final String? errorMessage;
  final DateTime? lastSyncAttempt;
  final bool isAutoSyncing;

  BackupState({
    this.isConnecting = false,
    this.isUploading = false,
    this.isDownloading = false,
    this.userEmail,
    this.lastBackupDate,
    this.errorMessage,
    this.lastSyncAttempt,
    this.isAutoSyncing = false,
  });

  BackupState copyWith({
    bool? isConnecting,
    bool? isUploading,
    bool? isDownloading,
    String? userEmail,
    DateTime? lastBackupDate,
    String? errorMessage,
    DateTime? lastSyncAttempt,
    bool? isAutoSyncing,
  }) {
    return BackupState(
      isConnecting: isConnecting ?? this.isConnecting,
      isUploading: isUploading ?? this.isUploading,
      isDownloading: isDownloading ?? this.isDownloading,
      userEmail: userEmail ?? this.userEmail,
      lastBackupDate: lastBackupDate ?? this.lastBackupDate,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      isAutoSyncing: isAutoSyncing ?? this.isAutoSyncing,
    );
  }
}

class BackupNotifier extends Notifier<BackupState> {
  final GoogleDriveService _driveService = GoogleDriveService();
  DateTime? _lastManualSyncTime;
  static const _minSyncInterval = Duration(minutes: 1);

  @override
  BackupState build() {
    // Inicialização assíncrona sem modificar o estado durante o build
    _init();
    return BackupState();
  }

  Future<void> _init() async {
    try {
      final account = await _driveService.silentSignIn;
      if (account != null) {
        final lastBackup = await _driveService.getLatestBackupDate();
        state = state.copyWith(
          userEmail: account.email,
          lastBackupDate: lastBackup,
        );
        // Tenta sincronizar automaticamente ao iniciar se estiver habilitado
        _tryAutoSync();
      }
    } catch (e) {
      // Erro silencioso durante inicialização
    }
  }

  Future<void> _tryAutoSync() async {
    try {
      final settings = ref.read(settingsProvider);
      
      // Verifica se auto-sync está habilitado
      if (!settings.autoSyncEnabled) return;
      
      // Verifica se está conectado ao Google Drive
      if (state.userEmail == null) return;
      
      // Verifica throttling - não sincroniza se foi sincronizado recentemente
      if (_lastManualSyncTime != null) {
        final timeSinceLastSync = DateTime.now().difference(_lastManualSyncTime!);
        if (timeSinceLastSync < _minSyncInterval) return;
      }
      
      // Verifica intervalo configurado
      if (state.lastSyncAttempt != null) {
        final timeSinceLastAttempt = DateTime.now().difference(state.lastSyncAttempt!);
        final configuredInterval = Duration(minutes: settings.syncIntervalMinutes);
        if (timeSinceLastAttempt < configuredInterval) return;
      }
      
      // Executa sincronização automática
      await _performAutoSync();
    } catch (e) {
      // Erro ao ler settings ou durante sync, ignora silenciosamente
    }
  }

  Future<void> _performAutoSync() async {
    if (state.isAutoSyncing) return; // Evita sincronizações simultâneas
    
    state = state.copyWith(isAutoSyncing: true, lastSyncAttempt: DateTime.now());
    
    try {
      final cloudBackupDate = await _driveService.getLatestBackupDate();
      
      if (cloudBackupDate == null) {
        // Não há backup na nuvem, faz upload
        await _driveService.uploadBackup();
      } else {
        // Verifica qual versão é mais recente
        final localLastModified = await _getLocalDatabaseLastModified();
        
        if (localLastModified != null) {
          final timeDifference = cloudBackupDate.difference(localLastModified);
          
          // Se a nuvem é mais recente por mais de 5 minutos, baixa
          // Se local é mais recente por mais de 5 minutos, sobe
          // Se a diferença é pequena, assume que são iguais e não faz nada
          if (timeDifference.abs() > const Duration(minutes: 5)) {
            if (timeDifference.isNegative) {
              // Local é mais recente, faz upload
              await _driveService.uploadBackup();
            } else {
              // Nuvem é mais recente, faz download
              await _driveService.downloadAndRestoreBackup();
            }
          }
        } else {
          // Não consegue determinar, faz upload por segurança
          await _driveService.uploadBackup();
        }
      }
      
      // Atualiza status
      final lastBackup = await _driveService.getLatestBackupDate();
      state = state.copyWith(lastBackupDate: lastBackup);
    } catch (e) {
      // Em caso de erro na sincronização automática, não mostra erro para o usuário
      // Apenas registra silenciosamente
    } finally {
      state = state.copyWith(isAutoSyncing: false);
    }
  }

  Future<DateTime?> _getLocalDatabaseLastModified() async {
    try {
      final dbPath = await _driveService.getDatabasePath();
      final file = File(dbPath);
      if (await file.exists()) {
        return await file.lastModified();
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  void triggerAutoSync() {
    _tryAutoSync();
  }

  Future<bool> signIn() async {
    state = state.copyWith(isConnecting: true, errorMessage: null);
    final account = await _driveService.signIn();
    if (account != null) {
      final lastBackup = await _driveService.getLatestBackupDate();
      state = state.copyWith(
        userEmail: account.email,
        lastBackupDate: lastBackup,
        isConnecting: false,
      );
      _tryAutoSync();
      return true;
    } else {
      state = state.copyWith(isConnecting: false, errorMessage: 'Falha ao conectar com Google');
      return false;
    }
  }

  Future<void> signOut() async {
    await _driveService.signOut();
    state = BackupState();
    _lastManualSyncTime = null;
  }

  Future<bool> uploadBackup() async {
    state = state.copyWith(isUploading: true, errorMessage: null);
    _lastManualSyncTime = DateTime.now();
    final success = await _driveService.uploadBackup();
    if (success) {
      final lastBackup = await _driveService.getLatestBackupDate();
      state = state.copyWith(isUploading: false, lastBackupDate: lastBackup, lastSyncAttempt: DateTime.now());
    } else {
      state = state.copyWith(isUploading: false, errorMessage: 'Falha ao enviar backup');
    }
    return success;
  }

  Future<bool> restoreBackup() async {
    state = state.copyWith(isDownloading: true, errorMessage: null);
    _lastManualSyncTime = DateTime.now();
    final success = await _driveService.downloadAndRestoreBackup();
    if (success) {
      state = state.copyWith(isDownloading: false, lastSyncAttempt: DateTime.now());
    } else {
      state = state.copyWith(isDownloading: false, errorMessage: 'Falha ao restaurar backup');
    }
    return success;
  }

  Future<void> refreshStatus() async {
    if (state.userEmail != null) {
      final lastBackup = await _driveService.getLatestBackupDate();
      state = state.copyWith(lastBackupDate: lastBackup);
    }
  }
}

final backupProvider = NotifierProvider<BackupNotifier, BackupState>(BackupNotifier.new);
