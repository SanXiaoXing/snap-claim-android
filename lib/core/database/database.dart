// 本地 SQLite 持久化：报销单（claims）+ 明细（records）。
// 单例 [AppDatabase.instance] 全局复用同一个 Database 实例。
import 'package:sqflite/sqflite.dart';

import '../../features/invoice/models/claim.dart';
import '../../features/invoice/models/record.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  /// 当前数据库 schema 版本，备份校验与 openDatabase 共用同一来源。
  static const int schemaVersion = 2;

  Database? _db;

  /// 数据库文件完整路径（sqflite 默认目录下的 snap_claim.db）。
  Future<String> dbFilePath() async {
    final dir = await getDatabasesPath();
    return '$dir/snap_claim.db';
  }

  /// 当前打开的数据库连接（惰性打开）。
  Future<Database> get database => _database();

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      '$dbPath/snap_claim.db',
      version: schemaVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE claims (
            id          TEXT PRIMARY KEY,
            name        TEXT NOT NULL DEFAULT '',
            start_date  INTEGER NOT NULL,
            end_date    INTEGER NOT NULL,
            saved_at    INTEGER NOT NULL,
            allowance   REAL NOT NULL DEFAULT 0,
            archived    INTEGER NOT NULL DEFAULT 0
          )
        ''');
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
      onUpgrade: (db, oldVersion, newVersion) async {
        // v2：新增 archived 列（归档 = 已报销）。
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE claims ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
    return _db!;
  }

  /// 加载全部报销单（含明细），按 savedAt 倒序返回。
  Future<List<Claim>> getAllClaims() async {
    final db = await _database();
    final claimRows = await db.query('claims', orderBy: 'saved_at DESC');
    final result = <Claim>[];
    for (final row in claimRows) {
      final recordRows = await db.query(
        'records',
        where: 'claim_id = ?',
        whereArgs: [row['id']],
        orderBy: 'sort_order ASC',
      );
      result.add(_claimFromRow(row, recordRows));
    }
    return result;
  }

  /// 插入或更新一张报销单（含明细）。
  /// 策略：先删旧明细 → 再 upsert 报销单 → 再插新明细，全部在事务内完成。
  Future<void> upsertClaim(Claim claim) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.delete('records', where: 'claim_id = ?', whereArgs: [claim.id]);
      await txn.insert(
        'claims',
        {
          'id': claim.id,
          'name': claim.name,
          'start_date': claim.startDate.millisecondsSinceEpoch,
          'end_date': claim.endDate.millisecondsSinceEpoch,
          'saved_at': claim.savedAt.millisecondsSinceEpoch,
          'allowance': claim.allowance,
          'archived': claim.archived ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var i = 0; i < claim.records.length; i++) {
        final r = claim.records[i];
        await txn.insert('records', {
          'id': r.id,
          'claim_id': claim.id,
          'category': r.category.name,
          'title': r.title,
          'subtitle': r.subtitle,
          'amount': r.amount,
          'car_trip_type': r.carTripType?.name,
          'sort_order': i,
        });
      }
    });
  }

  /// 从备份数据库文件合并导入：仅导入当前库中不存在的报销单（按 id 去重），
  /// 已存在的报销单保持当前版本不变；返回实际导入的张数。
  Future<int> mergeClaimsFromBackup(String backupPath) async {
    final db = await _database();
    final backup = await openDatabase(backupPath);
    try {
      final claimRows = await backup.query('claims');
      var imported = 0;
      await db.transaction((txn) async {
        for (final row in claimRows) {
          final id = row['id'] as String;
          final exists = await txn.query(
            'claims',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [id],
          );
          if (exists.isNotEmpty) continue;
          final recordRows = await backup.query(
            'records',
            where: 'claim_id = ?',
            whereArgs: [id],
            orderBy: 'sort_order ASC',
          );
          await txn.insert('claims', row, conflictAlgorithm: ConflictAlgorithm.ignore);
          for (final record in recordRows) {
            await txn.insert('records', record);
          }
          imported++;
        }
      });
      return imported;
    } finally {
      await backup.close();
    }
  }

  /// 删除一张报销单及其全部明细。
  Future<void> deleteClaim(String id) async {
    final db = await _database();
    await db.delete('records', where: 'claim_id = ?', whereArgs: [id]);
    await db.delete('claims', where: 'id = ?', whereArgs: [id]);
  }

  /// 关闭并释放数据库连接（导入备份替换文件前调用），
  /// 下次访问时自动重新打开。
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Claim _claimFromRow(Map<String, Object?> row, List<Map<String, Object?>> recordRows) {
    return Claim(
      id: row['id'] as String,
      name: row['name'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch(row['start_date'] as int),
      endDate: DateTime.fromMillisecondsSinceEpoch(row['end_date'] as int),
      savedAt: DateTime.fromMillisecondsSinceEpoch(row['saved_at'] as int),
      allowance: (row['allowance'] as num?)?.toDouble() ?? 0,
      archived: (row['archived'] as int? ?? 0) != 0,
      records: recordRows.map(_recordFromRow).toList(),
    );
  }

  Record _recordFromRow(Map<String, Object?> row) {
    return Record(
      id: row['id'] as String,
      category: RecordCategory.values.byName(row['category'] as String),
      title: row['title'] as String,
      subtitle: row['subtitle'] as String,
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      carTripType: (row['car_trip_type'] as String?) != null
          ? CarTripType.values.byName(row['car_trip_type'] as String)
          : null,
    );
  }
}
