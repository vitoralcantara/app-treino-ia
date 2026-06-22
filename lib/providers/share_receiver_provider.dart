import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../services/backup_service.dart';
import 'workout_provider.dart';

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
    // Iniciar monitoramento de intents quando o provider é criado, mas apenas em plataformas suportadas
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _startMonitoring();
    }
    return ShareReceiverState();
  }

  void _startMonitoring() {
    try {
      debugPrint('Iniciando monitoramento de intents de compartilhamento');

      // Monitorar intents enquanto o app está rodando
      _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> files) {
          debugPrint('Intent recebido enquanto app está rodando');
          _processSharedFiles(files);
        },
        onError: (error) {
          debugPrint('Erro no stream de intents: $error');
          state = state.copyWith(lastError: 'Erro ao receber arquivo: $error');
        },
      );

      // Verificar se o app foi aberto através de um intent (cold start)
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
        debugPrint('Verificando mídia inicial (cold start): ${files.length} arquivos');
        if (files.isNotEmpty) {
          _processSharedFiles(files);
        }
      }).catchError((e) {
        debugPrint('Erro ao buscar mídia inicial: $e');
      });
    } catch (e) {
      debugPrint('ReceiveSharingIntent não suportado nesta plataforma: $e');
    }
  }

  Future<void> _processSharedFiles(List<SharedMediaFile> files) async {
    debugPrint('Arquivos recebidos para compartilhamento: ${files.length}');
    if (files.isEmpty) return;

    // Procurar por arquivos JSON
    for (var file in files) {
      debugPrint('Arquivo recebido: ${file.path}, tipo: ${file.type}');
      if (file.path.toLowerCase().endsWith('.json')) {
        debugPrint('Arquivo JSON encontrado, processando: ${file.path}');
        await _processJsonFile(file.path);
        break; // Processa apenas o primeiro arquivo JSON encontrado
      }
    }
    debugPrint('Nenhum arquivo JSON encontrado');
  }

  Future<void> _processJsonFile(String filePath) async {
    debugPrint('Processando arquivo JSON: $filePath');
    state = state.copyWith(isProcessing: true, lastProcessedFile: filePath);

    try {
      debugPrint('Chamando importBackupFromFile');
      final result = await _backupService.importBackupFromFile(filePath);
      debugPrint('Resultado da importação: $result');

      if (result != null) {
        // Forçar recarregamento total dos providers após a restauração
        ref.invalidate(workoutListProvider);
        ref.invalidate(sessionListProvider);
        ref.invalidate(exerciseListProvider);
        ref.invalidate(routineProgressProvider);

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
      debugPrint('Erro ao processar arquivo JSON: $e');
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
