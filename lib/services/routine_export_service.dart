import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
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
