import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/google_drive_service.dart';

class BackupState {
  final bool isConnecting;
  final bool isUploading;
  final bool isDownloading;
  final String? userEmail;
  final DateTime? lastBackupDate;
  final String? errorMessage;

  BackupState({
    this.isConnecting = false,
    this.isUploading = false,
    this.isDownloading = false,
    this.userEmail,
    this.lastBackupDate,
    this.errorMessage,
  });

  BackupState copyWith({
    bool? isConnecting,
    bool? isUploading,
    bool? isDownloading,
    String? userEmail,
    DateTime? lastBackupDate,
    String? errorMessage,
  }) {
    return BackupState(
      isConnecting: isConnecting ?? this.isConnecting,
      isUploading: isUploading ?? this.isUploading,
      isDownloading: isDownloading ?? this.isDownloading,
      userEmail: userEmail ?? this.userEmail,
      lastBackupDate: lastBackupDate ?? this.lastBackupDate,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class BackupNotifier extends StateNotifier<BackupState> {
  final GoogleDriveService _driveService = GoogleDriveService();

  BackupNotifier() : super(BackupState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isConnecting: true);
    final account = await _driveService.silentSignIn;
    if (account != null) {
      final lastBackup = await _driveService.getLatestBackupDate();
      state = state.copyWith(
        userEmail: account.email,
        lastBackupDate: lastBackup,
        isConnecting: false,
      );
    } else {
      state = state.copyWith(isConnecting: false);
    }
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
      return true;
    } else {
      state = state.copyWith(isConnecting: false, errorMessage: 'Falha ao conectar com Google');
      return false;
    }
  }

  Future<void> signOut() async {
    await _driveService.signOut();
    state = BackupState();
  }

  Future<bool> uploadBackup() async {
    state = state.copyWith(isUploading: true, errorMessage: null);
    final success = await _driveService.uploadBackup();
    if (success) {
      final lastBackup = await _driveService.getLatestBackupDate();
      state = state.copyWith(isUploading: false, lastBackupDate: lastBackup);
    } else {
      state = state.copyWith(isUploading: false, errorMessage: 'Falha ao enviar backup');
    }
    return success;
  }

  Future<bool> restoreBackup() async {
    state = state.copyWith(isDownloading: true, errorMessage: null);
    final success = await _driveService.downloadAndRestoreBackup();
    if (success) {
      state = state.copyWith(isDownloading: false);
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

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>((ref) {
  return BackupNotifier();
});
