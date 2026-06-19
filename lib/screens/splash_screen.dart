import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/workout_provider.dart';
import '../providers/share_receiver_provider.dart';
import 'home_screen.dart';
import 'workout_execution_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Iniciar carregamento de dados em segundo plano enquanto a animação roda
    _preloadData();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          final activeWorkoutId = prefs.getInt('active_workout_id');
          
          if (activeWorkoutId != null && mounted) {
            // Se houver um treino ativo, tentamos encontrá-lo
            final workouts = ref.read(workoutListProvider);
            final activeWorkout = workouts.where((w) => w.id == activeWorkoutId).firstOrNull;
            
            if (activeWorkout != null) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => WorkoutExecutionScreen(workout: activeWorkout)),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          } else if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
          
          // Verificar se houve importação automática e mostrar mensagem
          _checkAutoImportResult();
        }
      });
    });
  }

  void _preloadData() {
    // Acessar os providers força a inicialização e o carregamento do banco de dados
    ref.read(workoutListProvider);
    ref.read(exerciseListProvider);
    ref.read(sessionListProvider);
    
    // Iniciar o monitoramento de arquivos compartilhados
    ref.read(shareReceiverProvider);
  }

  void _checkAutoImportResult() {
    // Usar Future.delayed para dar tempo ao provider processar o arquivo
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      final shareState = ref.read(shareReceiverProvider);
      
      if (shareState.lastSuccessMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shareState.lastSuccessMessage!),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Limpar a mensagem após mostrar
        ref.read(shareReceiverProvider.notifier).clearMessages();
      } else if (shareState.lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shareState.lastError!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        // Limpar a mensagem após mostrar
        ref.read(shareReceiverProvider.notifier).clearMessages();
      }
    });
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Fundo escuro condizente com o tema
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'logo-ia.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'TREINO IA',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sua evolução inteligente',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade300,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
