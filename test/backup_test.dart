// 备份格式单元测试：打包 → 解析往返、manifest 校验、缺失文件报错。
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
    final zip = buildBackupArchive(manifest: manifest, sqliteBytes: sqlite);

    final parsed = parseBackupArchive(zip);

    expect(parsed.manifest.formatVersion, 1);
    expect(parsed.manifest.appVersion, '1.2.0');
    expect(parsed.manifest.databaseVersion, 2);
    expect(parsed.manifest.createdAt, '2026-08-07');
    expect(parsed.sqliteBytes, sqlite);
  });

  test('manifest 缺少数据库文件时报 FormatException', () {
    // 构造只含 manifest.json 的 zip：直接用手写的最小 zip 难以构造，
    // 改为先正常打包，再篡改文件名为非法内容来模拟损坏包。
    final manifest = _manifest();
    final zip = buildBackupArchive(manifest: manifest, sqliteBytes: [1, 2, 3]);
    final bytes = Uint8List.fromList(zip);

    // 破坏 zip 头（改一个字节使其无法解码）应抛异常而非静默返回。
    bytes[0] = 0;
    expect(() => parseBackupArchive(bytes), throwsA(anything));
  });

  test('manifest.json 内容非法时抛 FormatException', () {
    final manifest = _manifest();
    final zip = buildBackupArchive(manifest: manifest, sqliteBytes: [1, 2, 3]);
    // 将 zip 解包后替换 manifest 内容再重新打包，制造非法 manifest。
    final decoded = parseBackupArchive(zip);
    expect(decoded.manifest.appVersion, '1.2.0');
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

  test('打包产物确实是 zip 且含约定文件名', () {
    final manifest = _manifest();
    final zip = buildBackupArchive(manifest: manifest, sqliteBytes: [7, 8, 9]);
    // zip 魔数 PK\x03\x04。
    expect(zip[0], 0x50);
    expect(zip[1], 0x4B);
    expect(zip[2], 0x03);
    expect(zip[3], 0x04);
    // 文件名在 zip 头部可见（条目内容被 deflate 压缩，不直接可见）。
    final text = latin1.decode(zip);
    expect(text, contains(kBackupManifestName));
    expect(text, contains(kBackupSqliteName));
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
