// 数据库迁移兼容性测试（真实 SQLite，sqflite_common_ffi）：
// - 模拟 v1 / v2 老库升级到当前 schema，验证老数据（报销单 + 明细）不丢失；
// - 新增列（archived / excess_amount）自动补默认值；
// - upgradeSchema 幂等：重复执行不因列已存在而崩溃；
// - 从旧版备份合并导入时缺列自动补默认值。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:snap_claim_android/core/database/database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('snapclaim_migrate_');
  });

  tearDown(() async {
    // 释放 AppDatabase 单例连接，避免占用临时目录文件导致删除失败。
    await AppDatabase.instance.close();
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  String claimsColumns({bool withArchived = false, bool withExcess = false}) {
    final cols = <String>[
      'id TEXT PRIMARY KEY',
      'name TEXT NOT NULL DEFAULT \'\'',
      'start_date INTEGER NOT NULL',
      'end_date INTEGER NOT NULL',
      'saved_at INTEGER NOT NULL',
      'allowance REAL NOT NULL DEFAULT 0',
      if (withArchived) 'archived INTEGER NOT NULL DEFAULT 0',
      if (withExcess) 'excess_amount REAL NOT NULL DEFAULT 0',
    ];
    return cols.join(', ');
  }

  /// 创建老版本 schema 的数据库文件并写入一条报销单 + 两条明细。
  Future<String> createOldDb({
    required int version,
    bool withArchived = false,
    bool withExcess = false,
  }) async {
    final path = '${tmpDir.path}/old_v$version.db';
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE claims (${claimsColumns(
            withArchived: withArchived,
            withExcess: withExcess,
          )})');
          await db.execute('''
            CREATE TABLE records (
              id            TEXT PRIMARY KEY,
              claim_id      TEXT NOT NULL,
              category      TEXT NOT NULL,
              title         TEXT NOT NULL DEFAULT '',
              subtitle      TEXT NOT NULL DEFAULT '',
              amount        REAL NOT NULL DEFAULT 0,
              car_trip_type TEXT,
              sort_order    INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (claim_id) REFERENCES claims(id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );
    await db.insert('claims', {
      'id': 'c_old_1',
      'name': '老报销单',
      'start_date': DateTime(2026, 7, 1).millisecondsSinceEpoch,
      'end_date': DateTime(2026, 7, 3).millisecondsSinceEpoch,
      'saved_at': DateTime(2026, 7, 3).millisecondsSinceEpoch,
      'allowance': 200.0,
      if (withArchived) 'archived': 1,
      if (withExcess) 'excess_amount': 150.0,
    });
    await db.insert('records', {
      'id': 'r_old_1',
      'claim_id': 'c_old_1',
      'category': 'train',
      'title': '火车票',
      'subtitle': '北京-上海',
      'amount': 553.0,
      'car_trip_type': null,
      'sort_order': 0,
    });
    await db.insert('records', {
      'id': 'r_old_2',
      'claim_id': 'c_old_1',
      'category': 'highway',
      'title': '高速费',
      'subtitle': '',
      'amount': 35.0,
      'car_trip_type': null,
      'sort_order': 1,
    });
    await db.close();
    return path;
  }

  /// 用当前 AppDatabase 的建表 / 升级逻辑打开数据库（模拟 App 升级启动）。
  Future<Database> openAsCurrent(String path) {
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => AppDatabase.createSchema(db),
        onUpgrade: (db, oldVersion, _) => AppDatabase.upgradeSchema(db, oldVersion),
      ),
    );
  }

  test('v1 老库（无 archived / excess_amount）升级后数据保留且新列默认 0', () async {
    final path = await createOldDb(version: 1);
    final db = await openAsCurrent(path);

    final claims = await db.query('claims');
    expect(claims.length, 1);
    expect(claims.first['id'], 'c_old_1');
    expect(claims.first['name'], '老报销单');
    expect(claims.first['allowance'], 200.0);
    // 新列由迁移补默认值，老数据不丢。
    expect(claims.first['archived'], 0);
    expect(claims.first['excess_amount'], 0);

    final recs = await db.query(
      'records',
      where: 'claim_id = ?',
      whereArgs: ['c_old_1'],
      orderBy: 'sort_order ASC',
    );
    expect(recs.length, 2);
    expect(recs.first['title'], '火车票');
    expect(recs.last['amount'], 35.0);
    await db.close();
  });

  test('v2 老库（有 archived 无 excess_amount）升级后 archived 保留且 excess 默认 0', () async {
    final path = await createOldDb(version: 2, withArchived: true);
    final db = await openAsCurrent(path);

    final claims = await db.query('claims');
    expect(claims.length, 1);
    // 已归档状态保留。
    expect(claims.first['archived'], 1);
    // 新增列补默认值。
    expect(claims.first['excess_amount'], 0);
    expect(claims.first['allowance'], 200.0);
    await db.close();
  });

  test('upgradeSchema 幂等：在已是最新 schema 的库上重复执行不崩溃', () async {
    final path = '${tmpDir.path}/current.db';
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: (db, _) => AppDatabase.createSchema(db),
      ),
    );
    // 手工重复执行迁移（模拟异常中断后重试），列已存在应被幂等跳过。
    await AppDatabase.upgradeSchema(db, 1);
    await AppDatabase.upgradeSchema(db, 2);
    await AppDatabase.upgradeSchema(db, AppDatabase.schemaVersion - 1);
    expect(await db.query('claims'), isEmpty);
    await db.close();
  });

  test('从 v1 老备份合并导入：缺列补默认值，老数据完整导入', () async {
    // 让 AppDatabase.instance 的当前库也落到临时目录，便于隔离验证。
    await databaseFactory.setDatabasesPath(tmpDir.path);
    // 老备份库（v1 schema，无 archived / excess_amount 列）。
    final backupPath = await createOldDb(version: 1);

    final merged = await AppDatabase.instance.mergeClaimsFromBackup(backupPath);
    expect(merged, 1);

    // 端到端验证：通过 AppDatabase 读回合并后的报销单。
    final claims = await AppDatabase.instance.getAllClaims();
    expect(claims.length, 1);
    expect(claims.first.name, '老报销单');
    // 老备份缺列，导入后自动补默认值。
    expect(claims.first.archived, isFalse);
    expect(claims.first.excessAmount, 0);
    expect(claims.first.allowance, 200.0);
    // 明细完整导入，不丢失。
    expect(claims.first.records.length, 2);
    expect(claims.first.records.first.title, '火车票');
    expect(claims.first.records.last.amount, 35.0);
  });
}
