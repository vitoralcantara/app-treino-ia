import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import 'archived_workouts_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _limitationsController = TextEditingController();
  final _apiKeyController = TextEditingController(); // Controlador para a API Key
  
  // Controladores de Medidas
  final _armController = TextEditingController();
  final _chestController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  final _thighController = TextEditingController();
  final _calfController = TextEditingController();

  String? _selectedGender;
  String? _selectedExperience;
  String? _selectedGoal;

  final List<String> _genderOptions = ['Masculino', 'Feminino', 'Outro', 'Prefiro não informar'];
  final List<String> _experienceOptions = ['Iniciante', 'Intermediário', 'Avançado'];
  final List<String> _goalOptions = ['Hipertrofia (Ganho de Massa)', 'Emagrecimento', 'Força', 'Condicionamento Físico', 'Saúde e Bem-estar'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    
    _ageController.text = profile.age;
    _weightController.text = profile.weight;
    _heightController.text = profile.height;
    _limitationsController.text = profile.limitations;
    _apiKeyController.text = settings.geminiApiKey ?? '';
    
    _armController.text = profile.arm;
    _chestController.text = profile.chest;
    _waistController.text = profile.waist;
    _hipController.text = profile.hip;
    _thighController.text = profile.thigh;
    _calfController.text = profile.calf;

    // Apenas preenche se o valor existir na lista, caso contrário deixa nulo
    if (_genderOptions.contains(profile.gender)) {
      _selectedGender = profile.gender;
    }
    if (_experienceOptions.contains(profile.experienceLevel)) {
      _selectedExperience = profile.experienceLevel;
    }
    if (_goalOptions.contains(profile.goal)) {
      _selectedGoal = profile.goal;
    }
  }

  void _saveProfile() {
    final profile = UserProfile(
      age: _ageController.text,
      weight: _weightController.text,
      height: _heightController.text,
      gender: _selectedGender ?? '',
      experienceLevel: _selectedExperience ?? '',
      goal: _selectedGoal ?? '',
      limitations: _limitationsController.text,
      arm: _armController.text,
      chest: _chestController.text,
      waist: _waistController.text,
      hip: _hipController.text,
      thigh: _thighController.text,
      calf: _calfController.text,
    );
    ref.read(profileProvider.notifier).saveProfile(profile);
    
    // Salvar API Key
    if (_apiKeyController.text.isNotEmpty) {
      ref.read(settingsProvider.notifier).saveApiKey(_apiKeyController.text);
    } else {
      ref.read(settingsProvider.notifier).clearApiKey();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil salvo com sucesso!')),
    );
  }

  void _showImportConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar Dados?'),
        content: const Text(
          'Atenção: A importação de um backup irá sobrescrever seus treinos e histórico atuais. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await BackupService().importBackup();
              if (result != null && context.mounted) {
                // Forçar recarregamento total dos providers após a restauração
                ref.invalidate(workoutListProvider);
                ref.invalidate(sessionListProvider);
                ref.invalidate(exerciseListProvider);
                ref.invalidate(routineProgressProvider);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result)),
                );
              }
            },
            child: const Text('Confirmar e Importar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Seu Perfil',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Estes dados serão enviados para a IA gerar treinos melhores para você.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(controller: _ageController, decoration: const InputDecoration(labelText: 'Idade', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: _weightController, decoration: const InputDecoration(labelText: 'Peso (kg)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: _heightController, decoration: const InputDecoration(labelText: 'Altura (cm)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Gênero', border: OutlineInputBorder()),
              initialValue: _selectedGender,
              items: _genderOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Nível de Experiência', border: OutlineInputBorder()),
              initialValue: _selectedExperience,
              items: _experienceOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedExperience = newValue;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Objetivo Principal', border: OutlineInputBorder()),
              initialValue: _selectedGoal,
              items: _goalOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedGoal = newValue;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(controller: _limitationsController, decoration: const InputDecoration(labelText: 'Lesões ou Limitações (Opcional)', border: OutlineInputBorder()), maxLines: 2),
            
            const SizedBox(height: 30),
            const Text(
              'Medidas Corporais (Opcional)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajuda a IA a focar em assimetrias ou áreas de interesse.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextField(controller: _armController, decoration: const InputDecoration(labelText: 'Braço (cm)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _chestController, decoration: const InputDecoration(labelText: 'Peito (cm)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _waistController, decoration: const InputDecoration(labelText: 'Cintura (cm)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _hipController, decoration: const InputDecoration(labelText: 'Quadril (cm)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _thighController, decoration: const InputDecoration(labelText: 'Coxa (cm)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _calfController, decoration: const InputDecoration(labelText: 'Panturrilha (cm)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              ],
            ),

            const SizedBox(height: 30),
            const Text(
              'Configurações e Histórico',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_edu, color: Colors.orangeAccent),
                title: const Text('Treinos Anteriores'),
                subtitle: const Text('Ver e retomar rotinas arquivadas'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ArchivedWorkoutsScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Gerenciamento de Dados',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.download, color: Colors.blue),
                    title: const Text('Exportar Backup'),
                    subtitle: const Text('Salvar todos os treinos e histórico'),
                    onTap: () async {
                      await BackupService().exportBackup();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup gerado com sucesso!')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.upload, color: Colors.green),
                    title: const Text('Importar Backup'),
                    subtitle: const Text('Restaurar dados de um arquivo JSON'),
                    onTap: () => _showImportConfirmation(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Sobre e Apoio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.purple),
                title: const Text('Sobre o App e Doações'),
                subtitle: const Text('Conheça o projeto e apoie o desenvolvimento'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showAboutDialog(context),
              ),
            ),

            const SizedBox(height: 30),
            const Text(
              'Integração IA Nativa',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gere treinos automaticamente dentro do app (BYOK).',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Google Gemini API Key (Opcional)',
                hintText: 'Cole sua chave AIzaSy...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 5),
            GestureDetector(
              onTap: () async {
                final url = Uri.parse('https://aistudio.google.com/app/apikey');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text(
                'Obter chave gratuita no Google AI Studio',
                style: TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
              ),
            ),

            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              label: const Text('Salvar Perfil'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sobre o Treino IA', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: AssetImage('logo-ia.png'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Versão 1.0.0',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'O Treino IA é um projeto independente de código aberto. Seu objetivo é democratizar o acesso a treinos estruturados usando o poder da Inteligência Artificial.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Apoie o Projeto! ☕',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Este app é gratuito e sem anúncios. Se ele te ajudou a evoluir nos treinos, considere fazer uma doação de qualquer valor para ajudar a manter o projeto vivo e receber novas atualizações.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'qr-code.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'PIX Copia e Cola',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  const myPixKey = '0002012636br.gov.bcb.pix0114+55119999999995204000053039865802BR5905BRL60040.006209SAO PAULO6304123463041A2B'; 
                  
                  Clipboard.setData(const ClipboardData(text: myPixKey));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chave PIX copiada! Obrigado pelo apoio ❤️'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar Chave PIX'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                  side: const BorderSide(color: Colors.greenAccent),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '*Substitua a chave no código pelo seu PIX real.',
                style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
