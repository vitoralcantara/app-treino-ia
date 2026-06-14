import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path/path.dart' as p;
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
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final file = File(dbPath);

      if (!await file.exists()) return false;

      // Procurar por backup anterior na appDataFolder
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = 'workout_app.db'",
      );

      final driveFile = drive.File();
      driveFile.name = 'workout_app.db';
      driveFile.parents = ['appDataFolder'];

      final media = drive.Media(file.openRead(), await file.length());

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Atualizar arquivo existente
        final existingFileId = fileList.files!.first.id!;
        await driveApi.files.update(driveFile, existingFileId, uploadMedia: media);
      } else {
        // Criar novo arquivo
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> downloadAndRestoreBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = 'workout_app.db'",
      );

      if (fileList.files == null || fileList.files!.isEmpty) return false;

      final fileId = fileList.files!.first.id!;
      // Versão segura de download
      final responseStream = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File(p.join(tempDir.path, 'restore.db'));
      
      final List<int> dataStore = [];
      await for (final data in responseStream.stream) {
        dataStore.addAll(data);
      }
      await tempFile.writeAsBytes(dataStore);

      await DatabaseHelper.instance.overwriteDatabase(tempFile.path);
      
      // Limpar temporário
      await tempDir.delete(recursive: true);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<DateTime?> getLatestBackupDate() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return null;

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = 'workout_app.db'",
      );

      if (fileList.files == null || fileList.files!.isEmpty) return null;

      return fileList.files!.first.modifiedTime;
    } catch (e) {
      return null;
    }
  }
}
