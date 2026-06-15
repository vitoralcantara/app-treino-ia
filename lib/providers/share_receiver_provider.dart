import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../services/backup_service.dart';

class ShareReceiverState {
  final bool isProcessing;
  final String? lastProcessedFile;
  final String? lastError;
  final String? lastSuccessMessage;

  ShareReceiverState({
    this.isProcessing = false,
    this.lastProcessedFile,
    this.lastError,
    this.lastSuccessMessage,
  });

  ShareReceiverState copyWith({
    bool? isProcessing,
    String? lastProcessedFile,
    String? lastError,
    String? lastSuccessMessage,
  }) {
    return ShareReceiverState(
      isProcessing: isProcessing ?? this.isProcessing,
      lastProcessedFile: lastProcessedFile ?? this.lastProcessedFile,
      lastError: lastError ?? this.lastError,
      lastSuccessMessage: lastSuccessMessage ?? this.lastSuccessMessage,
    );
  }
}

class ShareReceiverNotifier extends Notifier<ShareReceiverState> {
  final BackupService _backupService = BackupService();
  StreamSubscription? _intentSubscription;

  @override
  ShareReceiverState build() {
    // Iniciar monitoramento de intents quando o provider é criado
    _startMonitoring();
    return ShareReceiverState();
  }

  void _startMonitoring() {
    // Monitorar intents enquanto o app está rodando
    _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        _processSharedFiles(files);
      },
      onError: (error) {
        state = state.copyWith(lastError: 'Erro ao receber arquivo: $error');
      },
    );

    // Verificar se o app foi aberto através de um intent (cold start)
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _processSharedFiles(files);
      }
    });
  }

  Future<void> _processSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    // Procurar por arquivos JSON
    for (var file in files) {
      if (file.path.toLowerCase().endsWith('.json')) {
        await _processJsonFile(file.path);
        break; // Processa apenas o primeiro arquivo JSON encontrado
      }
    }
  }

  Future<void> _processJsonFile(String filePath) async {
    state = state.copyWith(isProcessing: true, lastProcessedFile: filePath);

    try {
      final result = await _backupService.importBackupFromFile(filePath);
      
      if (result != null) {
        state = state.copyWith(
          isProcessing: false,
          lastSuccessMessage: result,
          lastError: null,
        );
      } else {
        state = state.copyWith(
          isProcessing: false,
          lastError: 'Falha ao importar arquivo JSON',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        lastError: 'Erro ao processar arquivo: $e',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(
      lastError: null,
      lastSuccessMessage: null,
    );
  }

  void disposeSubscription() {
    _intentSubscription?.cancel();
  }
}

final shareReceiverProvider = NotifierProvider<ShareReceiverNotifier, ShareReceiverState>(ShareReceiverNotifier.new);
