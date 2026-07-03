import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/backup_provider.dart';
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
  final _apiKeyController = TextEditingController(); 
  
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

  Timer? _debounceTimer;
  bool _isUpdatingFromSource = false;

  @override
  void initState() {
    super.initState();
    
    // Inicializar valores dos controladores a partir do provider
    final profile = ref.read(profileProvider);
    final settings = ref.read(settingsProvider);
    
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

    _selectedGender = _genderOptions.contains(profile.gender) ? profile.gender : null;
    _selectedExperience = _experienceOptions.contains(profile.experienceLevel) ? profile.experienceLevel : null;
    _selectedGoal = _goalOptions.contains(profile.goal) ? profile.goal : null;

    // Adicionar listeners para auto-save
    _ageController.addListener(_onFieldChanged);
    _weightController.addListener(_onFieldChanged);
    _heightController.addListener(_onFieldChanged);
    _limitationsController.addListener(_onFieldChanged);
    _apiKeyController.addListener(_onFieldChanged);
    _armController.addListener(_onFieldChanged);
    _chestController.addListener(_onFieldChanged);
    _waistController.addListener(_onFieldChanged);
    _hipController.addListener(_onFieldChanged);
    _thighController.addListener(_onFieldChanged);
    _calfController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _limitationsController.dispose();
    _apiKeyController.dispose();
    _armController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _thighController.dispose();
    _calfController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_isUpdatingFromSource) return;
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _performSave();
    });
  }

  void _performSave() {
    if (!mounted) return;

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
    
    // Apenas salva se houver mudança real para evitar loops
    final currentProfile = ref.read(profileProvider);
    if (profile.toJson() != currentProfile.toJson()) {
      ref.read(profileProvider.notifier).saveProfile(profile);
    }
    
    // Salvar API Key se houver mudança
    final currentApiKey = ref.read(settingsProvider).geminiApiKey ?? '';
    if (_apiKeyController.text != currentApiKey) {
      if (_apiKeyController.text.isNotEmpty) {
        ref.read(settingsProvider.notifier).saveApiKey(_apiKeyController.text);
      } else {
        ref.read(settingsProvider.notifier).clearApiKey();
      }
    }
  }

  void _updateControllersFromProfile(UserProfile profile) {
    setState(() {
      _isUpdatingFromSource = true;
      
      // Apenas atualiza se o texto for diferente para não perder a posição do cursor
      if (_ageController.text != profile.age) _ageController.text = profile.age;
      if (_weightController.text != profile.weight) _weightController.text = profile.weight;
      if (_heightController.text != profile.height) _heightController.text = profile.height;
      if (_limitationsController.text != profile.limitations) _limitationsController.text = profile.limitations;
      
      if (_armController.text != profile.arm) _armController.text = profile.arm;
      if (_chestController.text != profile.chest) _chestController.text = profile.chest;
      if (_waistController.text != profile.waist) _waistController.text = profile.waist;
      if (_hipController.text != profile.hip) _hipController.text = profile.hip;
      if (_thighController.text != profile.thigh) _thighController.text = profile.thigh;
      if (_calfController.text != profile.calf) _calfController.text = profile.calf;

      _selectedGender = _genderOptions.contains(profile.gender) ? profile.gender : null;
      _selectedExperience = _experienceOptions.contains(profile.experienceLevel) ? profile.experienceLevel : null;
      _selectedGoal = _goalOptions.contains(profile.goal) ? profile.goal : null;
      
      _isUpdatingFromSource = false;
    });
  }

  String _getSyncStatusText(DateTime syncTime) {
    final now = DateTime.now();
    final difference = now.difference(syncTime);

    if (difference.inMinutes < 1) {
      return 'Agora mesmo';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min atrás';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h atrás';
    } else {
      return DateFormat('dd/MM').format(syncTime);
    }
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
                ref.invalidate(profileProvider);
                
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

  void _showCloudRestoreConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar da Nuvem?'),
        content: const Text(
          'Atenção: A restauração do Google Drive irá substituir todos os seus dados locais pelos dados salvos na nuvem.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(backupProvider.notifier).restoreBackup();
              if (success && context.mounted) {
                ref.invalidate(workoutListProvider);
                ref.invalidate(sessionListProvider);
                ref.invalidate(exerciseListProvider);
                ref.invalidate(routineProgressProvider);
                ref.invalidate(profileProvider);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup restaurado com sucesso do Google Drive!')),
                );
              } else if (context.mounted) {
                final error = ref.read(backupProvider).errorMessage ?? 'Erro desconhecido';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Confirmar e Restaurar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupState = ref.watch(backupProvider);
    final settings = ref.watch(settingsProvider);

    // Escutar mudanças externas no perfil (ex: cloud restore) para atualizar controladores
    ref.listen(profileProvider, (previous, next) {
      if (!_isUpdatingFromSource) {
        _updateControllersFromProfile(next);
      }
    });

    // Escutar mudanças externas na API Key
    ref.listen(settingsProvider, (previous, next) {
      if (next.geminiApiKey != _apiKeyController.text && !_isUpdatingFromSource) {
        _apiKeyController.text = next.geminiApiKey ?? '';
      }
    });

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Seu Perfil',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Estes dados são salvos automaticamente conforme você preenche.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
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
                _performSave();
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
                _performSave();
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
                _performSave();
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
              'Backup em Nuvem (Google Drive)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    if (backupState.userEmail == null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Conectar com Google'),
                        onPressed: backupState.isConnecting 
                          ? null 
                          : () => ref.read(backupProvider.notifier).signIn(),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 45),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                        ),
                      )
                    else
                      Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(
                              backupState.userEmail!,
                              maxLines: null,
                              softWrap: true,
                            ),
                            subtitle: Text(
                              backupState.lastBackupDate == null
                                ? 'Nenhum backup encontrado'
                                : 'Último backup: ${DateFormat('dd/MM/yyyy HH:mm').format(backupState.lastBackupDate!)}'
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.logout),
                              onPressed: () => ref.read(backupProvider.notifier).signOut(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: backupState.isUploading 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.cloud_upload),
                                  label: const Text('Fazer Backup'),
                                  onPressed: backupState.isUploading 
                                    ? null 
                                    : () async {
                                        final success = await ref.read(backupProvider.notifier).uploadBackup();
                                        if (success && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Backup enviado com sucesso!')),
                                          );
                                        }
                                      },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: backupState.isDownloading 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.cloud_download),
                                  label: const Text('Restaurar'),
                                  onPressed: backupState.isDownloading 
                                    ? null 
                                    : () => _showCloudRestoreConfirmation(context, ref),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),
            // Configurações de Auto-Sync (apenas quando conectado)
            if (backupState.userEmail != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sync, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Sincronização Automática',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          // Indicador visual de status de sincronização
                          if (backupState.isAutoSyncing)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Sincronizando...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            )
                          else if (backupState.lastSyncAttempt != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Sync: ${_getSyncStatusText(backupState.lastSyncAttempt!)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Icon(
                              Icons.sync_problem,
                              size: 16,
                              color: Colors.grey,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text(
                          'Sincronizar automaticamente',
                          maxLines: null,
                          softWrap: true,
                        ),
                        subtitle: const Text('Faz backup/restauração automática quando há mudanças'),
                        value: settings.autoSyncEnabled,
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).setAutoSyncEnabled(value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text(
                          'Sincronizar apenas em Wi-Fi',
                          maxLines: null,
                          softWrap: true,
                        ),
                        subtitle: const Text('Economiza dados móveis'),
                        value: settings.syncOnWifiOnly,
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).setSyncOnWifiOnly(value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      ListTile(
                        title: const Text(
                          'Intervalo de sincronização',
                          maxLines: null,
                          softWrap: true,
                        ),
                        subtitle: Text('${settings.syncIntervalMinutes} minutos'),
                        trailing: DropdownButton<int>(
                          value: settings.syncIntervalMinutes,
                          items: [5, 15, 30, 60, 120].map((minutes) {
                            return DropdownMenuItem<int>(
                              value: minutes,
                              child: Text('$minutes min'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              ref.read(settingsProvider.notifier).setSyncIntervalMinutes(value);
                            }
                          },
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text(
                          'Auto-selecionar próxima série',
                          maxLines: null,
                          softWrap: true,
                        ),
                        subtitle: const Text('Ao reiniciar o timer, marca a próxima série automaticamente'),
                        value: settings.autoSelectNextSet,
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).setAutoSelectNextSet(value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
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
                title: const Text(
                  'Treinos Anteriores',
                  maxLines: null,
                  softWrap: true,
                ),
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
              'Gerenciamento de Arquivos Locais',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.download, color: Colors.blue),
                    title: const Text(
                      'Exportar Backup JSON',
                      maxLines: null,
                      softWrap: true,
                    ),
                    subtitle: const Text('Salvar em arquivo manual'),
                    onTap: () async {
                      await BackupService().exportBackup();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup JSON gerado com sucesso!')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.upload, color: Colors.green),
                    title: const Text(
                      'Importar Backup JSON',
                      maxLines: null,
                      softWrap: true,
                    ),
                    subtitle: const Text('Restaurar de um arquivo JSON'),
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
                title: const Text(
                  'Sobre o App e Doações',
                  maxLines: null,
                  softWrap: true,
                ),
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
            const SizedBox(height: 50),
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
