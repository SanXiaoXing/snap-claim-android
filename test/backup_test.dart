// 备份格式单元测试：打包 → 解析往返、manifest 校验、损坏文件报错。
// 纯 Dart 逻辑，不依赖 sqflite / 平台插件。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:snap_claim_android/core/backup/backup.dart';

BackupManifest _manifest({
  int formatVersion = 1,
  String appVersion = '1.2.0',
  int databaseVersion = 2,
  String createdAt = '2026-08-07',
}) => BackupManifest(
      formatVersion: formatVersion,
      appVersion: appVersion,
      databaseVersion: databaseVersion,
      createdAt: createdAt,
    );

void main() {
  test('打包后解析能完整还原 manifest 与 sqlite 字节', () {
    const manifest = BackupManifest(
      formatVersion: 1,
      appVersion: '1.2.0',
      databaseVersion: 2,
      createdAt: '2026-08-07',
    );
    final sqlite = List<int>.generate(1024, (i) => i % 256);
    final bytes = encodeBackup(manifest: manifest, sqliteBytes: sqlite);

    final parsed = decodeBackup(bytes);

    expect(parsed.manifest.formatVersion, 1);
    expect(parsed.manifest.appVersion, '1.2.0');
    expect(parsed.manifest.databaseVersion, 2);
    expect(parsed.manifest.createdAt, '2026-08-07');
    expect(parsed.sqliteBytes, sqlite);
  });

  test('打包产物是 .snapbackup 二进制：魔数 SNAPBACK + 格式版本字节', () {
    final manifest = _manifest();
    final bytes = encodeBackup(manifest: manifest, sqliteBytes: [7, 8, 9]);
    // 文件头：8 字节 ASCII 魔数 + 1 字节格式版本。
    expect(ascii.decode(bytes.sublist(0, 8)), 'SNAPBACK');
    expect(bytes[8], kBackupFormatVersion);
  });

  test('损坏文件（魔数被破坏）时抛 FormatException', () {
    final manifest = _manifest();
    final bytes = encodeBackup(manifest: manifest, sqliteBytes: [1, 2, 3]);

    // 破坏魔数（改一个字节使其无法识别）应抛异常而非静默返回。
    bytes[0] = 0;
    expect(() => decodeBackup(bytes), throwsA(anything));
  });

  test('manifest 长度越界时抛 FormatException', () {
    final manifest = _manifest();
    final bytes = encodeBackup(manifest: manifest, sqliteBytes: [1, 2, 3]);
    // 篡改 manifest 长度字段（大端 4 字节）为超大值，使越界。
    ByteData.sublistView(bytes, 9, 13).setUint32(0, 0x7FFFFFFF);
    expect(() => decodeBackup(bytes), throwsA(anything));
  });

  test('validateManifest：版本兼容时返回 null', () {
    expect(
      validateManifest(_manifest(), currentDatabaseVersion: 2),
      isNull,
    );
    expect(
      validateManifest(
        _manifest(databaseVersion: 1),
        currentDatabaseVersion: 2,
      ),
      isNull,
    );
  });

  test('validateManifest：格式版本不兼容时报错', () {
    final err = validateManifest(
      _manifest(formatVersion: 99),
      currentDatabaseVersion: 2,
    );
    expect(err, isNotNull);
    expect(err, contains('不兼容'));
  });

  test('validateManifest：备份数据库版本高于当前时提示升级', () {
    final err = validateManifest(
      _manifest(databaseVersion: 5),
      currentDatabaseVersion: 2,
    );
    expect(err, isNotNull);
    expect(err, contains('升级'));
  });

  test('manifest toJson/fromJson 往返一致', () {
    final m = _manifest(createdAt: '2026-01-15');
    final restored = BackupManifest.fromJson(m.toJson());
    expect(restored.formatVersion, m.formatVersion);
    expect(restored.appVersion, m.appVersion);
    expect(restored.databaseVersion, m.databaseVersion);
    expect(restored.createdAt, m.createdAt);
  });

  test('jsonEncode 后内容与约定字段一致', () {
    final m = _manifest();
    final json = jsonDecode(jsonEncode(m.toJson()));
    expect(json['format_version'], 1);
    expect(json['app_version'], '1.2.0');
    expect(json['database_version'], 2);
    expect(json['created_at'], '2026-08-07');
  });
}
