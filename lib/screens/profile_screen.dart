import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';

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
    _ageController.text = profile.age;
    _weightController.text = profile.weight;
    _heightController.text = profile.height;
    _limitationsController.text = profile.limitations;

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
    );
    ref.read(profileProvider.notifier).saveProfile(profile);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil salvo com sucesso!')),
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
            const SizedBox(height: 20),
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
}

