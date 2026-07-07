import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../data/database_helper.dart';

class BackupService {
  static const String _lastBackupKey = 'last_backup_timestamp';
  static const String _firstInstallationKey = 'first_installation_date';

  Future<void> exportBackup() async {
    final db = DatabaseHelper.instance;
    
    // Coletar todos os dados
    final exercises = await db.getAllExercises();
    final allWorkouts = await db.getAllWorkouts(); // Pega ativos e inativos
    final sessions = await db.getAllSessions();
    final archivedRoutines = await db.getArchivedRoutines();
    
    // Coletar pesos padrão para todos os exercícios
    final exerciseIds = exercises.map((e) => e.id!).toList();
    final defaultWeights = await db.getAllExerciseDefaultWeights(exerciseIds);
    
    // Converter para formato serializável
    final defaultWeightsList = <Map<String, dynamic>>[];
    defaultWeights.forEach((exerciseId, sets) {
      for (int i = 0; i < sets.length; i++) {
        final set = sets[i];
        defaultWeightsList.add({
          'exercise_id': exerciseId,
          'reps': set.reps,
          'weight': set.weight,
          'position': i,
          'technique': set.technique,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    });

    final backupData = {
      'version': 2, // Atualizado para versão 2 para incluir pesos padrão
      'exported_at': DateTime.now().toIso8601String(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'workouts': allWorkouts.map((w) => w.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'archived_routines': archivedRoutines.map((r) => r.toJson()).toList(),
      'exercise_default_weights': defaultWeightsList,
    };

    final String jsonString = jsonEncode(backupData);
    
    if (kIsWeb) {
      // No web, podemos usar Share para texto
      await Share.share(
        jsonString,
        subject: 'Meu Backup de Treinos - Treino IA',
      );
    } else {
      // Salvar em arquivo temporário para compartilhar
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/treino_ia_backup_${_getFormattedDate()}.json');
      await file.writeAsString(jsonString);

      // Abrir menu de compartilhamento
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Meu Backup de Treinos - Treino IA',
      );
    }
    
    // Atualizar data do último backup
    await _updateLastBackupDate();
  }

  Future<String?> importBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null && result.files.single.bytes == null) return null;

      if (kIsWeb) {
        if (result.files.single.bytes != null) {
          final jsonString = utf8.decode(result.files.single.bytes!);
          return await _importBackupFromJson(jsonString);
        }
        return "Erro: Bytes do arquivo não disponíveis no web.";
      } else {
        return await importBackupFromFile(result.files.single.path!);
      }
    } catch (e) {
      return "Erro ao restaurar backup: $e";
    }
  }

  Future<String?> importBackupFromFile(String filePath) async {
    if (kIsWeb) return "Importação de arquivo por path não suportada no Web.";
    try {
      final pickedFile = File(filePath);
      final jsonString = await pickedFile.readAsString();
      return await _importBackupFromJson(jsonString);
    } catch (e) {
      return "Erro ao restaurar backup: $e";
    }
  }

  Future<String?> _importBackupFromJson(String jsonString) async {
    try {
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      // Validação básica de formato
      if (!backupData.containsKey('workouts') || !backupData.containsKey('exercises')) {
        throw Exception('Arquivo de backup inválido.');
      }

      await DatabaseHelper.instance.restoreFromBackup(backupData);
      await _updateLastBackupDate();

      return "Backup restaurado com sucesso!";
    } catch (e) {
      return "Erro ao restaurar backup: $e";
    }
  }

  Future<bool> shouldShowBackupReminder({bool autoSyncEnabled = true}) async {
    // Se auto-sync está ativo, não mostrar lembrete de backup
    if (autoSyncEnabled) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Registrar primeira instalação se não existir
    if (!prefs.containsKey(_firstInstallationKey)) {
      await prefs.setInt(_firstInstallationKey, DateTime.now().millisecondsSinceEpoch);
    }
    
    final firstInstallationMillis = prefs.getInt(_firstInstallationKey)!;
    final firstInstallation = DateTime.fromMillisecondsSinceEpoch(firstInstallationMillis);
    final now = DateTime.now();
    
    // Só mostrar lembrete após 30 dias de uso do app
    if (now.difference(firstInstallation).inDays < 30) {
      return false;
    }

    final lastBackupMillis = prefs.getInt(_lastBackupKey) ?? 0;
    
    // Se nunca fez backup, mostrar lembrete após 30 dias de uso
    if (lastBackupMillis == 0) return true;

    final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastBackupMillis);
    
    // Se passou 30 dias desde o último backup, mostrar lembrete
    return now.difference(lastBackup).inDays >= 30;
  }

  Future<void> _updateLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return '${now.day}_${now.month}_${now.year}';
  }
}
