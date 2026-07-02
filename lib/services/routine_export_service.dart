import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/routine.dart';

class RoutineExportService {
  static Future<void> exportRoutineAsTxt(Routine routine) async {
    final StringBuffer sb = StringBuffer();
    final dateFormat = DateFormat('dd/MM/yyyy');

    sb.writeln('========================================');
    sb.writeln('ROTINA DE TREINO: ${routine.name.toUpperCase()}');
    sb.writeln('========================================');
    sb.writeln('Criada em: ${dateFormat.format(routine.createdAt)}');
    
    if (routine.suggestedDurationWeeks != null) {
      sb.writeln('Duração sugerida: ${routine.suggestedDurationWeeks} semanas');
    }

    final frequency = _getFrequencyLabel(routine);
    sb.writeln('Frequência: $frequency');
    sb.writeln();

    for (var workout in routine.workouts) {
      sb.writeln('----------------------------------------');
      sb.writeln('TREINO: ${workout.name}');
      sb.writeln('----------------------------------------');
      
      if (workout.exercises.isEmpty) {
        sb.writeln('(Nenhum exercício adicionado)');
      } else {
        for (int i = 0; i < workout.exercises.length; i++) {
          final ex = workout.exercises[i];
          sb.writeln('${i + 1}. ${ex.name}');
          
          if (ex.category != null && ex.category!.isNotEmpty) {
            sb.writeln('   Categoria: ${ex.category}');
          }
          
          if (ex.suggestedSets != null || ex.suggestedReps != null || ex.suggestedRepsList != null) {
            String target = '   Meta: ';
            if (ex.suggestedSets != null) target += '${ex.suggestedSets} séries';
            if (ex.suggestedReps != null) target += ' x ${ex.suggestedReps} reps';
            else if (ex.suggestedRepsList != null) target += ' x [${ex.suggestedRepsList}] reps';
            sb.writeln(target);
          }

          if (ex.technique != null && ex.technique!.isNotEmpty) {
            sb.writeln('   Técnica: ${ex.technique}');
          }

          if (ex.workoutSpecificNotes != null && ex.workoutSpecificNotes!.isNotEmpty) {
            sb.writeln('   Notas: ${ex.workoutSpecificNotes}');
          }
          sb.writeln();
        }
      }
      sb.writeln();
    }

    sb.writeln('Gerado por: Power - App de Treino IA');
    sb.writeln('========================================');

    await Share.share(
      sb.toString(),
      subject: 'Minha Rotina de Treino: ${routine.name}',
    );
  }

  static Future<void> exportRoutineAsDoc(Routine routine) async {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final StringBuffer sb = StringBuffer();

    sb.writeln('<html><head><meta charset="utf-8"></head><body>');
    sb.writeln('<h1 style="text-align: center; color: #2c3e50;">Rotina de Treino: ${routine.name}</h1>');
    sb.writeln('<p style="text-align: center; color: #7f8c8d;">Criada em: ${dateFormat.format(routine.createdAt)}</p>');
    
    if (routine.suggestedDurationWeeks != null) {
      sb.writeln('<p style="text-align: center;"><strong>Duração sugerida:</strong> ${routine.suggestedDurationWeeks} semanas</p>');
    }

    final frequency = _getFrequencyLabel(routine);
    sb.writeln('<p style="text-align: center;"><strong>Frequência:</strong> $frequency</p>');
    sb.writeln('<hr>');

    for (var workout in routine.workouts) {
      sb.writeln('<h2 style="background-color: #ecf0f1; padding: 10px; color: #2980b9; border-left: 5px solid #2980b9;">Treino: ${workout.name}</h2>');
      
      if (workout.exercises.isEmpty) {
        sb.writeln('<p><em>Nenhum exercício adicionado</em></p>');
      } else {
        sb.writeln('<table border="1" style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">');
        sb.writeln('<tr style="background-color: #34495e; color: white;">');
        sb.writeln('<th style="padding: 8px;">#</th><th style="padding: 8px;">Exercício</th><th style="padding: 8px;">Meta</th><th style="padding: 8px;">Técnica/Notas</th>');
        sb.writeln('</tr>');

        for (int i = 0; i < workout.exercises.length; i++) {
          final ex = workout.exercises[i];
          String target = '';
          if (ex.suggestedSets != null) target += '${ex.suggestedSets} séries';
          if (ex.suggestedReps != null) target += ' x ${ex.suggestedReps} reps';
          else if (ex.suggestedRepsList != null) target += ' x [${ex.suggestedRepsList}] reps';

          String notes = '';
          if (ex.technique != null && ex.technique!.isNotEmpty) notes += '<strong>Técnica:</strong> ${ex.technique}<br>';
          if (ex.workoutSpecificNotes != null && ex.workoutSpecificNotes!.isNotEmpty) notes += '<strong>Notas:</strong> ${ex.workoutSpecificNotes}';

          sb.writeln('<tr>');
          sb.writeln('<td style="padding: 8px; text-align: center;">${i + 1}</td>');
          sb.writeln('<td style="padding: 8px;"><strong>${ex.name}</strong><br><small>${ex.category ?? ""}</small></td>');
          sb.writeln('<td style="padding: 8px; text-align: center;">$target</td>');
          sb.writeln('<td style="padding: 8px;">$notes</td>');
          sb.writeln('</tr>');
        }
        sb.writeln('</table>');
      }
    }

    sb.writeln('<footer style="margin-top: 30px; text-align: center; font-size: 10px; color: #bdc3c7;">');
    sb.writeln('Gerado por Power - App de Treino IA');
    sb.writeln('</footer>');
    sb.writeln('</body></html>');

    final directory = await getTemporaryDirectory();
    final fileName = 'Rotina_${routine.name.replaceAll(' ', '_')}.doc';
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(utf8.encode(sb.toString()));

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Minha Rotina de Treino: ${routine.name}',
    );
  }

  static String _getFrequencyLabel(Routine routine) {
    if (routine.frequencyType == null) return 'Não definida';
    switch (routine.frequencyType) {
      case 'daily': return 'Diariamente';
      case 'weekdays': return 'Dias de Semana (Seg-Sex)';
      case 'weekly': return 'Semanal (${routine.frequencyValue ?? ""})';
      default: return 'Personalizada';
    }
  }
}
