import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import '../data/database_helper.dart';

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  GoogleSignInAccount? _currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (error) {
      debugPrint('GoogleSignIn: Erro no login: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<GoogleSignInAccount?> get silentSignIn async {
    _currentUser = await _googleSignIn.signInSilently();
    return _currentUser;
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = _currentUser ?? await silentSignIn;
    if (account == null) return null;

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;

    return drive.DriveApi(httpClient);
  }

  Future<bool> uploadBackup() async {
    try {
      debugPrint('[BACKUP] Iniciando processo de backup...');

      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        debugPrint('[BACKUP] Erro: Drive API não disponível');
        return false;
      }

      // Garantir que os dados do WAL sejam movidos para o arquivo principal .db
      debugPrint('[BACKUP] Executando checkpoint do SQLite...');
      await DatabaseHelper.instance.checkpoint();

      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final file = File(dbPath);

      if (!await file.exists()) {
        debugPrint('[BACKUP] Erro: Arquivo de banco de dados não encontrado');
        return false;
      }

      // Criar arquivo ZIP com metadados JSON
      debugPrint('[BACKUP] Criando arquivo ZIP com metadados...');
      final archive = Archive();

      // Adicionar banco de dados ao ZIP
      final dbBytes = await file.readAsBytes();
      archive.addFile(ArchiveFile('workout_app.db', dbBytes.length, dbBytes));

      // Criar metadados JSON
      final dbFile = File(dbPath);
      debugPrint('[BACKUP] Gerando metadados...');
      final lastModified = await dbFile.lastModified();

      // Buscar dados reais para logar o que está sendo salvo
      final db = await DatabaseHelper.instance.database;
      final workouts = await db.query('workouts');
      final sessions = await db.query('workout_sessions');
      debugPrint('[BACKUP] Conteúdo que será salvo: ${workouts.length} treinos e ${sessions.length} sessões.');
      if (workouts.isNotEmpty) {
        debugPrint('[BACKUP] Exemplo de treinos: ${workouts.map((w) => w['name']).take(3).toList()}');
      }

      final backupMetadata = {
        'version': '2.0',
        'timestamp': DateTime.now().toIso8601String(),
        'databaseModified': lastModified.toIso8601String(),
        'platform': Platform.operatingSystem,
        'appVersion': '1.0.0',
        'content_summary': {
          'workouts_count': workouts.length,
          'sessions_count': sessions.length,
        }
      };

      final jsonBytes = utf8.encode(jsonEncode(backupMetadata));
      archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

      debugPrint('[BACKUP] Codificando ZIP...');
      final zipData = ZipEncoder().encode(archive);

      if (zipData == null) {
        debugPrint('[BACKUP] Erro: Falha ao codificar ZIP');
        return false;
      }

      // Procurar por backup anterior na appDataFolder
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = 'treino_ia_backup.zip'",
      );

      final driveFile = drive.File();
      driveFile.name = 'treino_ia_backup.zip';
      driveFile.appProperties = {
        'workouts_count': workouts.length.toString(),
        'sessions_count': sessions.length.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      final media = drive.Media(
        Stream.fromIterable([zipData]),
        zipData.length,
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        debugPrint('[BACKUP] Atualizando arquivo existente no Drive...');
        final existingFileId = fileList.files!.first.id!;
        
        // No update do v3, enviamos o objeto driveFile com o nome e as appProperties
        await driveApi.files.update(driveFile, existingFileId, uploadMedia: media);
      } else {
        debugPrint('[BACKUP] Criando novo arquivo no Drive...');
        driveFile.parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      debugPrint('[BACKUP] Processo de backup concluído com sucesso');
      return true;
    } catch (e) {
      debugPrint('[BACKUP] Erro durante backup: $e');
      return false;
    }
  }

  Future<bool> downloadAndRestoreBackup() async {
    try {
      debugPrint('[RESTORE] Iniciando processo de restore...');

      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        debugPrint('[RESTORE] Erro: Drive API não disponível');
        return false;
      }

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = 'treino_ia_backup.zip'",
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('[RESTORE] Erro: Nenhum arquivo de backup encontrado');
        return false;
      }

      final remoteFile = fileList.files!.first;
      debugPrint('[RESTORE] Arquivo de backup encontrado: ${remoteFile.name}');
      debugPrint('[RESTORE] Modificado em: ${remoteFile.modifiedTime}');

      final fileId = remoteFile.id!;

      // Download do ZIP
      debugPrint('[RESTORE] Baixando arquivo ZIP...');
      final responseStream = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final List<int> dataStore = [];
      await for (final data in responseStream.stream) {
        dataStore.addAll(data);
      }

      debugPrint('[RESTORE] Decodificando ZIP...');
      final archive = ZipDecoder().decodeBytes(dataStore);

      // Procurar backup.json no ZIP para metadados
      String? metadataJson;
      File? dbFile;

      for (final file in archive) {
        if (file.isFile) {
          if (file.name == 'backup.json') {
            metadataJson = utf8.decode(file.content as List<int>);
            debugPrint('[RESTORE] Metadados encontrados: ${metadataJson.substring(0, metadataJson.length > 100 ? 100 : metadataJson.length)}...');
          } else if (file.name == 'workout_app.db') {
            final tempDir = await Directory.systemTemp.createTemp();
            dbFile = File(p.join(tempDir.path, 'restore.db'));
            await dbFile.writeAsBytes(file.content as List<int>);
          }
        }
      }

      if (dbFile == null) {
        debugPrint('[RESTORE] Erro: Arquivo de banco de dados não encontrado no ZIP');
        return false;
      }

      debugPrint('[RESTORE] Restaurando banco de dados...');
      await DatabaseHelper.instance.overwriteDatabase(dbFile.path);

      // Logar conteúdo restaurado para depuração
      try {
        final db = await DatabaseHelper.instance.database;
        final workouts = await db.query('workouts');
        final sessions = await db.query('workout_sessions');
        debugPrint('[RESTORE] Dados carregados após restore: ${workouts.length} treinos, ${sessions.length} sessões');
        if (workouts.isNotEmpty) {
          debugPrint('[RESTORE] Nomes dos treinos restaurados: ${workouts.map((w) => w['name']).toList()}');
        }
      } catch (e) {
        debugPrint('[RESTORE] Aviso: Não foi possível ler o banco após o restore para log: $e');
      }

      // Limpar temporário
      await dbFile.parent.delete(recursive: true);

      debugPrint('[RESTORE] Processo de restore concluído com sucesso');
      return true;
    } catch (e) {
      debugPrint('[RESTORE] Erro durante restore: $e');
      return false;
    }
  }

  Future<drive.File?> getLatestBackupFile() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = 'treino_ia_backup.zip'",
        fields: 'files(id, name, modifiedTime, appProperties)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) return null;

      return fileList.files!.first;
    } catch (e) {
      debugPrint('[BACKUP] Erro ao buscar arquivo do backup: $e');
      return null;
    }
  }

  Future<DateTime?> getLatestBackupDate() async {
    final file = await getLatestBackupFile();
    return file?.modifiedTime;
  }

  Future<String> getDatabasePath() async {
    return await DatabaseHelper.instance.getDatabasePath();
  }
}
