import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import 'settings_provider.dart';

final aiServiceProvider = Provider<AiService?>((ref) {
  final settings = ref.watch(settingsProvider);
  final apiKey = settings.geminiApiKey;
  
  if (apiKey == null || apiKey.isEmpty) {
    return null;
  }
  
  return AiService(apiKey: apiKey);
});
