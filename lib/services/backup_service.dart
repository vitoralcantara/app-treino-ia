import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database_helper.dart';

class BackupService {
  static const String _lastBackupKey = 'last_backup_timestamp';

  Future<void> exportBackup() async {
    final db = DatabaseHelper.instance;
    
    // Coletar todos os dados
    final exercises = await db.getAllExercises();
    final allWorkouts = await db.getAllWorkouts(); // Pega ativos e inativos
    final sessions = await db.getAllSessions();
    final archivedRoutines = await db.getArchivedRoutines();

    final backupData = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'workouts': allWorkouts.map((w) => w.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'archived_routines': archivedRoutines.map((r) => r.toJson()).toList(),
    };

    final String jsonString = jsonEncode(backupData);
    
    // Salvar em arquivo temporário para compartilhar
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/treino_ia_backup_${_getFormattedDate()}.json');
    await file.writeAsString(jsonString);

    // Abrir menu de compartilhamento (Usa API atualizada do share_plus)
    await Share.shareXFiles([XFile(file.path)], text: 'Meu Backup de Treinos - Treino IA');
    
    // Atualizar data do último backup
    await _updateLastBackupDate();
  }

  Future<bool> shouldShowBackupReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackupMillis = prefs.getInt(_lastBackupKey) ?? 0;
    
    if (lastBackupMillis == 0) return true; // Nunca fez backup

    final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastBackupMillis);
    final now = DateTime.now();
    
    // Diferença maior que 30 dias
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
