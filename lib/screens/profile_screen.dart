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
    _ageController.text = profile.age;
    _weightController.text = profile.weight;
    _heightController.text = profile.height;
    _limitationsController.text = profile.limitations;
    
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

