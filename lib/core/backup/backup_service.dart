// 备份服务：导出 / 导入 .snapbackup（自定义二进制：魔数 + manifest + sqlite）。
// 纯数据格式逻辑见 backup.dart，本文件负责数据库快照、文件 IO 与保存/选择。
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import '../utils/format.dart';
import 'backup.dart';

/// 备份失败（格式不合法 / 版本不兼容等）时抛出的用户可读错误。
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

/// 备份 / 恢复服务。
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// SharedPreferences 中「最后备份日期」的键（yyyy-MM-dd）。
  static const String _lastBackupKey = 'lastBackupDate';

  /// 生成 .snapbackup 字节：VACUUM INTO 一致性快照 + 打包为 .snapbackup。
  Future<Uint8List> buildBackupBytes() async {
    final db = await AppDatabase.instance.database;
    final tmpDir = await getTemporaryDirectory();
    final tmpFile =
        File('${tmpDir.path}/snapclaim_${DateTime.now().millisecondsSinceEpoch}.sqlite');
    try {
      // VACUUM INTO 生成一致性快照（SQLite 3.27+），避免复制活跃库文件不一致。
      await db.execute("VACUUM INTO '${tmpFile.path}'");
    } catch (_) {
      // 旧版 SQLite 不支持 VACUUM INTO：退化为直接复制数据库文件。
      final src = File(await AppDatabase.instance.dbFilePath());
      await src.copy(tmpFile.path);
    }
    final sqliteBytes = await tmpFile.readAsBytes();
    try {
      await tmpFile.delete();
    } catch (_) {} // 临时文件删除失败不影响导出结果。
    final manifest = BackupManifest(
      formatVersion: kBackupFormatVersion,
      appVersion: kAppVersion,
      databaseVersion: AppDatabase.schemaVersion,
      createdAt: fmtDateDashed(DateTime.now()),
    );
    return encodeBackup(manifest: manifest, sqliteBytes: sqliteBytes);
  }

  /// 导出备份：生成 .snapbackup 字节 → 弹保存对话框。
  /// 返回保存路径；用户取消返回 null。
  Future<String?> export() async {
    final bytes = await buildBackupBytes();
    final today = fmtDateDashed(DateTime.now());
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '保存备份',
      fileName: 'SnapClaim_$today.snapbackup',
      bytes: bytes,
    );
    if (path != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, today);
    }
    return path;
  }

  /// 选择 .snapbackup 文件并解析、校验。
  /// 返回文件内解析出的 sqlite 字节（未落盘）。
  Future<({BackupManifest manifest, List<int> sqliteBytes})> pickAndValidate()
      async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: const ['snapbackup'],
    );
    final path = result?.files.single.path;
    if (path == null) throw const BackupException('未选择备份文件');
    final bytes = await File(path).readAsBytes();
    final parsed = decodeBackup(Uint8List.fromList(bytes));
    final error =
        validateManifest(parsed.manifest, currentDatabaseVersion: AppDatabase.schemaVersion);
    if (error != null) throw BackupException(error);
    return parsed;
  }

  /// 用备份中的 sqlite 字节替换当前数据库文件（调用前须已关闭连接）。
  Future<void> restore(List<int> sqliteBytes) async {
    await AppDatabase.instance.close();
    final target = File(await AppDatabase.instance.dbFilePath());
    await target.writeAsBytes(sqliteBytes, flush: true);
  }

  /// 最近一次备份日期（yyyy-MM-dd），从未备份返回 null。
  Future<String?> lastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBackupKey);
  }

  /// 当前数据库文件大小（字节），文件不存在返回 0。
  Future<int> databaseSizeBytes() async {
    final f = File(await AppDatabase.instance.dbFilePath());
    if (!await f.exists()) return 0;
    return f.length();
  }
}
