import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/drive/v3.dart' show DetailedApiRequestError;
import 'package:http/http.dart' as http;

import 'import_service.dart' show ImportException;

class GoogleDriveService {
  static const _driveScope = 'https://www.googleapis.com/auth/drive.appdata';
  static const _backupFileName = 'bible_flashcards_backup.json';
  static const _maxBackupFiles = 3;
  static const _maxRestoreBytes = 5 * 1024 * 1024;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static const _driveSignedInKey = 'drive_signed_in';

  // `??=` ensures initialize() is called exactly once even under concurrent calls
  static Future<void>? _initFuture;

  static Future<void> _ensureInitialized() =>
      _initFuture ??= GoogleSignIn.instance.initialize();

  Future<bool> get isSignedIn async {
    final flag = await _secureStorage.read(key: _driveSignedInKey);
    return flag == 'true';
  }

  Future<GoogleSignInAccount> signIn() async {
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    // Store intent flag only — never store tokens or account email
    await _secureStorage.write(key: _driveSignedInKey, value: 'true');
    return account;
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.disconnect();
    await _secureStorage.delete(key: _driveSignedInKey);
  }

  Future<void> backup(String jsonContent) async {
    final client = await _buildAuthClient();
    if (client == null) throw Exception('Not signed in to Google Drive');

    try {
      final driveApi = drive.DriveApi(client);
      await _retryWithBackoff(() => _uploadBackup(driveApi, jsonContent));
      // Best-effort prune — don't fail backup if pruning errors
      final errors = <Object>[];
      await _pruneOldBackups(driveApi, errors: errors);
    } finally {
      client.close();
    }
  }

  Future<String?> restore() async {
    final client = await _buildAuthClient();
    if (client == null) return null;

    try {
      final driveApi = drive.DriveApi(client);
      return await _retryWithBackoff(() => _downloadLatestBackup(driveApi));
    } finally {
      client.close();
    }
  }

  Future<void> deleteBackup() async {
    final client = await _buildAuthClient();
    if (client == null) throw Exception('Not signed in to Google Drive');

    try {
      final driveApi = drive.DriveApi(client);
      await _retryWithBackoff(() => _deleteAllBackups(driveApi));
    } finally {
      client.close();
    }
  }

  Future<_AuthClient?> _buildAuthClient() async {
    await _ensureInitialized();
    GoogleSignInAccount? account;
    try {
      account = await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (_) {
      // Token revoked or no prior session — self-heal the flag
      await _secureStorage.delete(key: _driveSignedInKey);
      return null;
    }
    if (account == null) {
      // Silent auth returned no account — clear stale flag
      await _secureStorage.delete(key: _driveSignedInKey);
      return null;
    }

    final headers = await account.authorizationClient.authorizationHeaders(
      [_driveScope],
    );
    if (headers == null) return null;
    return _AuthClient(headers);
  }

  Future<void> _uploadBackup(drive.DriveApi api, String content) async {
    final bytes = utf8.encode(content);
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final meta = drive.File()
      ..name = _backupFileName
      ..parents = ['appDataFolder'];
    await api.files.create(meta, uploadMedia: media);
  }

  Future<String?> _downloadLatestBackup(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      orderBy: 'createdTime desc',
      pageSize: 1,
      $fields: 'files(id)',
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    final id = files.first.id;
    if (id == null) return null;

    final response = await api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final chunks = <List<int>>[];
    var totalBytes = 0;
    await for (final chunk in response.stream) {
      totalBytes += chunk.length;
      if (totalBytes > _maxRestoreBytes) {
        throw const ImportException('Backup file too large (max 5 MB)');
      }
      chunks.add(chunk);
    }
    return utf8.decode(chunks.expand((c) => c).toList());
  }

  Future<void> _pruneOldBackups(
    drive.DriveApi api, {
    required List<Object> errors,
  }) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      orderBy: 'createdTime desc',
      pageSize: 100,
      $fields: 'files(id)',
    );
    final files = list.files;
    if (files == null || files.length <= _maxBackupFiles) return;
    // Attempt all deletes; collect errors to avoid partial failure halting pruning
    for (final file in files.skip(_maxBackupFiles)) {
      if (file.id != null) {
        try {
          await api.files.delete(file.id!);
        } catch (e) {
          errors.add(e);
        }
      }
    }
  }

  Future<void> _deleteAllBackups(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      pageSize: 100,
      $fields: 'files(id)',
    );
    final files = list.files;
    if (files == null) return;
    final errors = <Object>[];
    for (final file in files) {
      if (file.id != null) {
        try {
          await api.files.delete(file.id!);
        } catch (e) {
          errors.add(e);
        }
      }
    }
    if (errors.isNotEmpty) {
      throw Exception('Failed to delete ${errors.length} backup file(s)');
    }
  }

  /// Exponential backoff: max 5 retries, cap 64s, +20% jitter.
  /// 4xx errors are rethrown immediately — retrying them wastes quota.
  Future<T> _retryWithBackoff<T>(Future<T> Function() fn) async {
    final rng = Random();
    for (var attempt = 0; attempt <= 5; attempt++) {
      try {
        return await fn();
      } catch (e) {
        // Non-transient client errors — rethrow immediately
        if (e is DetailedApiRequestError) {
          final status = e.status;
          if (status != null && status >= 400 && status < 500) rethrow;
        }
        if (attempt == 5) rethrow;
        final baseMs = min(pow(2, attempt).toInt() * 1000, 64000);
        final jitter = (baseMs * 0.2 * rng.nextDouble()).toInt();
        await Future<void>.delayed(Duration(milliseconds: baseMs + jitter));
      }
    }
    throw StateError('Retry loop exhausted');
  }
}

/// HTTP client that injects Google OAuth authorization headers.
class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);

  final Map<String, String> _headers;
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
