// 备份文件格式：zip 内含 manifest.json + snapclaim.sqlite。
// 纯数据逻辑（不依赖平台插件），可单元测试。
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 备份格式版本：决定 .snapbackup 内部结构是否兼容。
const int kBackupFormatVersion = 1;

/// 当前 App 版本号（写入 manifest，供导入时展示/校验来源版本）。
const String kAppVersion = '1.1.0';

/// 备份 zip 内的文件名约定。
const String kBackupManifestName = 'manifest.json';
const String kBackupSqliteName = 'snapclaim.sqlite';

/// 备份 manifest：记录格式 / App / 数据库版本与创建时间，供导入时校验。
class BackupManifest {
  final int formatVersion;
  final String appVersion;
  final int databaseVersion;
  final String createdAt; // yyyy-MM-dd

  const BackupManifest({
    required this.formatVersion,
    required this.appVersion,
    required this.databaseVersion,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'format_version': formatVersion,
        'app_version': appVersion,
        'database_version': databaseVersion,
        'created_at': createdAt,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
        formatVersion: json['format_version'] as int? ?? 0,
        appVersion: json['app_version'] as String? ?? '',
        databaseVersion: json['database_version'] as int? ?? 0,
        createdAt: json['created_at'] as String? ?? '',
      );
}

/// 打包备份：manifest + sqlite 快照 → zip 字节。
Uint8List buildBackupArchive({
  required BackupManifest manifest,
  required List<int> sqliteBytes,
}) {
  final archive = Archive();
  final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
  archive.addFile(ArchiveFile(
    kBackupManifestName,
    manifestBytes.length,
    manifestBytes,
  ));
  archive.addFile(ArchiveFile(
    kBackupSqliteName,
    sqliteBytes.length,
    sqliteBytes,
  ));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// 解析备份 zip：返回 manifest 与 sqlite 字节；结构非法抛 FormatException。
({BackupManifest manifest, List<int> sqliteBytes}) parseBackupArchive(
  Uint8List bytes,
) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final manifestFile = archive.findFile(kBackupManifestName);
  final sqliteFile = archive.findFile(kBackupSqliteName);
  if (manifestFile == null || sqliteFile == null) {
    throw const FormatException('备份文件缺少 manifest.json 或 snapclaim.sqlite');
  }
  final json = jsonDecode(utf8.decode(manifestFile.content as List<int>));
  final manifest = BackupManifest.fromJson(json as Map<String, dynamic>);
  return (manifest: manifest, sqliteBytes: sqliteFile.content as List<int>);
}

/// 校验 manifest 是否可导入；返回 null 表示可导入，否则返回错误文案。
String? validateManifest(
  BackupManifest manifest, {
  required int currentDatabaseVersion,
}) {
  if (manifest.formatVersion != kBackupFormatVersion) {
    return '备份格式版本（v${manifest.formatVersion}）与本应用'
        '（v$kBackupFormatVersion）不兼容';
  }
  if (manifest.databaseVersion > currentDatabaseVersion) {
    return '备份来自更新版本的应用（数据库 v${manifest.databaseVersion}），'
        '请先升级 App 后再导入';
  }
  return null;
}
