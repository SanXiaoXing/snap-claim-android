// 备份文件格式：自定义 .snapbackup 二进制（非 zip）。
// 布局：魔数(8B "SNAPBACK") + 格式版本(1B) + manifest 长度(4B 大端) +
//       manifest JSON(UTF-8) + sqlite 快照字节。
// 纯数据逻辑（不依赖平台插件），可单元测试。
import 'dart:convert';
import 'dart:typed_data';

/// 备份格式版本：决定 .snapbackup 内部结构是否兼容。
const int kBackupFormatVersion = 1;

/// 当前 App 版本号（写入 manifest，供导入时展示/校验来源版本）。
const String kAppVersion = '1.2.1';

/// .snapbackup 文件头魔数（8 字节 ASCII），用于快速识别文件类型。
const String kBackupMagic = 'SNAPBACK';

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

/// 打包备份：魔数 + 格式版本 + manifest + sqlite 快照 → .snapbackup 字节。
Uint8List encodeBackup({
  required BackupManifest manifest,
  required List<int> sqliteBytes,
}) {
  final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
  final bb = BytesBuilder(copy: false)
    ..add(ascii.encode(kBackupMagic))
    ..addByte(kBackupFormatVersion)
    ..add(_u32be(manifestBytes.length))
    ..add(manifestBytes)
    ..add(sqliteBytes);
  return bb.toBytes();
}

/// 解析 .snapbackup 文件：返回 manifest 与 sqlite 字节；结构非法抛 FormatException。
({BackupManifest manifest, List<int> sqliteBytes}) decodeBackup(
  Uint8List bytes,
) {
  // 头 = 魔数 8 + 格式版本 1 + manifest 长度 4。
  const headerLen = 8 + 1 + 4;
  if (bytes.length < headerLen) {
    throw const FormatException('备份文件过短或已损坏');
  }
  if (ascii.decode(bytes.sublist(0, 8)) != kBackupMagic) {
    throw const FormatException('不是有效的 .snapbackup 备份文件');
  }
  if (bytes[8] != kBackupFormatVersion) {
    throw FormatException('备份格式版本（v${bytes[8]}）与本应用'
        '（v$kBackupFormatVersion）不兼容');
  }
  final manifestLen = ByteData.sublistView(bytes, 9, headerLen).getUint32(0);
  final manifestEnd = headerLen + manifestLen;
  if (manifestEnd > bytes.length) {
    throw const FormatException('备份文件损坏：manifest 长度越界');
  }
  final json =
      jsonDecode(utf8.decode(bytes.sublist(headerLen, manifestEnd)));
  final manifest = BackupManifest.fromJson(json as Map<String, dynamic>);
  return (manifest: manifest, sqliteBytes: bytes.sublist(manifestEnd));
}

/// 4 字节大端无符号整数（Dart 默认即大端）。
Uint8List _u32be(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v);

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
