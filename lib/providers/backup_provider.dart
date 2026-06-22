import 'dart:io';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/google_drive_service.dart';
import '../data/database_helper.dart';
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

class BackupNotifier extends Notifier<BackupState> with WidgetsBindingObserver {
  final GoogleDriveService _driveService = GoogleDriveService();
  DateTime? _lastManualSyncTime;
  static const _minSyncInterval = Duration(minutes: 1);
  Timer? _syncTimer;

  @override
  BackupState build() {
    // Inicialização assíncrona
    _init();
    
    // Configurar observador de ciclo de vida
    WidgetsBinding.instance.addObserver(this);
    
    // Observar mudanças no intervalo de sincronização para atualizar o timer
    ref.listen(settingsProvider.select((s) => s.syncIntervalMinutes), (prev, next) {
      if (state.userEmail != null) {
        _startSyncTimer();
      }
    });

    // Limpar ao descartar o provider
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _syncTimer?.cancel();
    });

    return BackupState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Tenta sincronizar ao retomar o app
      _tryAutoSync(force: true);
    }
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
        // Tenta sincronizar automaticamente ao iniciar
        _tryAutoSync();
        
        // Iniciar timer periódico
        _startSyncTimer();
      }
    } catch (e) {
      // Erro silencioso durante inicialização
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    final settings = ref.read(settingsProvider);
    
    // Timer para verificar mudanças periodicamente
    _syncTimer = Timer.periodic(Duration(minutes: settings.syncIntervalMinutes), (timer) {
      _tryAutoSync();
    });
  }

  Future<void> _tryAutoSync({bool force = false}) async {
    try {
      debugPrint('[SYNC] Verificando condições para sincronização automática (force: $force)...');
      final settings = ref.read(settingsProvider);

      // Verifica se auto-sync está habilitado
      if (!settings.autoSyncEnabled) {
        debugPrint('[SYNC] Auto-sync desabilitado nas configurações');
        return;
      }

      // Verifica se está conectado ao Google Drive
      if (state.userEmail == null) {
        debugPrint('[SYNC] Não conectado ao Google Drive');
        return;
      }

      if (!force) {
        debugPrint('[SYNC] Verificando throttling e intervalo configurado...');

        // Verifica throttling - não sincroniza se foi sincronizado recentemente manualmente
        if (_lastManualSyncTime != null) {
          final timeSinceLastSync = DateTime.now().difference(_lastManualSyncTime!);
          if (timeSinceLastSync < _minSyncInterval) {
            debugPrint('[SYNC] Throttling: muito recente desde sync manual (${timeSinceLastSync.inSeconds}s)');
            return;
          }
        }

        // Verifica intervalo configurado
        if (state.lastSyncAttempt != null) {
          final timeSinceLastAttempt = DateTime.now().difference(state.lastSyncAttempt!);
          final configuredInterval = Duration(minutes: settings.syncIntervalMinutes);
          if (timeSinceLastAttempt < configuredInterval) {
            debugPrint('[SYNC] Intervalo configurado não atingido (${timeSinceLastAttempt.inMinutes}/${configuredInterval.inMinutes} minutos)');
            return;
          }
        }
      }

      debugPrint('[SYNC] Condições atendidas, executando sincronização automática...');
      // Executa sincronização automática
      await _performAutoSync();
    } catch (e) {
      debugPrint('[SYNC] Erro ao verificar condições: $e');
      // Erro silencioso
    }
  }

  Future<void> _performAutoSync() async {
    if (state.isAutoSyncing) {
      debugPrint('[SYNC] Já está sincronizando, ignorando...');
      return; // Evita sincronizações simultâneas
    }

    debugPrint('[SYNC] Iniciando sincronização automática...');
    state = state.copyWith(isAutoSyncing: true, lastSyncAttempt: DateTime.now());

    try {
      final cloudBackupDate = await _driveService.getLatestBackupDate();

      if (cloudBackupDate == null) {
        debugPrint('[SYNC] Não há backup na nuvem, fazendo upload...');
        // Não há backup na nuvem, faz upload
        await _driveService.uploadBackup();
      } else {
        debugPrint('[SYNC] Backup na nuvem encontrado: $cloudBackupDate');
        // Verifica qual versão é mais recente
        final localLastModified = await _getLocalDatabaseLastModified();

        if (localLastModified != null) {
          debugPrint('[SYNC] Última modificação local: $localLastModified');
          final timeDifference = cloudBackupDate.difference(localLastModified);
          debugPrint('[SYNC] Diferença de tempo: ${timeDifference.inMinutes} minutos');

          // Se a nuvem é mais recente por mais de 1 minuto, baixa
          // Se local é mais recente por mais de 1 minuto, sobe
          if (timeDifference.abs() > const Duration(minutes: 1)) {
            if (timeDifference.isNegative) {
              debugPrint('[SYNC] Local é mais recente, fazendo upload...');
              // Local é mais recente, faz upload
              await _driveService.uploadBackup();
            } else {
              // Nuvem é mais recente - verifica se é primeira sincronização
              if (state.lastBackupDate == null) {
                debugPrint('[SYNC] Primeira sincronização detectada, verificando se há dados locais...');
                // Verificar se há dados locais significativos antes de sobrescrever
                final hasLocalData = await _hasSignificantLocalData();
                if (hasLocalData) {
                  debugPrint('[SYNC] Dados locais encontrados, fazendo upload em vez de download para proteger dados do usuário');
                  await _driveService.uploadBackup();
                } else {
                  debugPrint('[SYNC] Sem dados locais significativos, fazendo download...');
                  await _driveService.downloadAndRestoreBackup();
                }
              } else {
                debugPrint('[SYNC] Nuvem é mais recente, fazendo download...');
                await _driveService.downloadAndRestoreBackup();
              }
            }
          } else {
            debugPrint('[SYNC] Dados estão sincronizados (diferença < 1 minuto)');
          }
        } else {
          debugPrint('[SYNC] Não consegue determinar data local, fazendo upload por segurança...');
          // Não consegue determinar, faz upload por segurança
          await _driveService.uploadBackup();
        }
      }

      // Atualiza status
      final lastBackup = await _driveService.getLatestBackupDate();
      debugPrint('[SYNC] Sincronização concluída. Último backup: $lastBackup');
      state = state.copyWith(lastBackupDate: lastBackup);
    } catch (e) {
      debugPrint('[SYNC] Erro durante sincronização: $e');
      // Erro silencioso
    } finally {
      state = state.copyWith(isAutoSyncing: false);
    }
  }

  Future<bool> _hasSignificantLocalData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final workouts = await db.query('workouts');
      final exercises = await db.query('exercises');
      final sessions = await db.query('workout_sessions');

      debugPrint('[SYNC] Dados locais: ${workouts.length} treinos, ${exercises.length} exercícios, ${sessions.length} sessões');

      // Considera dados significativos se houver pelo menos um treino ou exercício
      return workouts.isNotEmpty || exercises.isNotEmpty;
    } catch (e) {
      debugPrint('[SYNC] Erro ao verificar dados locais: $e');
      return false;
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
    _tryAutoSync(force: true);
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
      _tryAutoSync(force: true);
      _startSyncTimer();
      return true;
    } else {
      state = state.copyWith(isConnecting: false, errorMessage: 'Falha ao conectar com Google');
      return false;
    }
  }

  Future<void> signOut() async {
    _syncTimer?.cancel();
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
