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
  final _genderController = TextEditingController();
  final _experienceController = TextEditingController();
  final _goalController = TextEditingController();
  final _limitationsController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = ref.watch(profileProvider);
    _ageController.text = profile.age;
    _weightController.text = profile.weight;
    _heightController.text = profile.height;
    _genderController.text = profile.gender;
    _experienceController.text = profile.experienceLevel;
    _goalController.text = profile.goal;
    _limitationsController.text = profile.limitations;
  }

  void _saveProfile() {
    final profile = UserProfile(
      age: _ageController.text,
      weight: _weightController.text,
      height: _heightController.text,
      gender: _genderController.text,
      experienceLevel: _experienceController.text,
      goal: _goalController.text,
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
            TextField(controller: _genderController, decoration: const InputDecoration(labelText: 'Gênero', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _experienceController, decoration: const InputDecoration(labelText: 'Nível de Experiência (ex: Iniciante)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _goalController, decoration: const InputDecoration(labelText: 'Objetivo Principal (ex: Hipertrofia)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _limitationsController, decoration: const InputDecoration(labelText: 'Lesões ou Limitações', border: OutlineInputBorder()), maxLines: 2),
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
