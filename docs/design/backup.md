> 保存用户已经整理好的发票数据，而不是保存原始票据文件。

---

## 收敛后的方案：Database Backup Only

目标：

```
导出：
SQLite数据库 → .snapbackup

导入：
.snapbackup → SQLite数据库恢复
```

不包含：

```
❌ PDF
❌ 图片
❌ OCR缓存文件
❌ 临时文件
```

---

# 1. 备份文件格式

仍然建议不要直接导出 `.db`。

用户看到：

```
snapclaim.db
```

没有产品感。

定义：

```
SnapClaim Backup
```

例如：

```
SnapClaim_2026-08-06.snapbackup
```

内部：

```
SnapClaim_2026-08-06.snapbackup

实际上:

SQLite Database File
+
Metadata
```

甚至可以直接：

```
.snapbackup = sqlite文件
```

但是我更推荐：

```
zip
```

结构：

```
SnapClaim_Backup.zip

├── manifest.json
└── snapclaim.sqlite
```

---

# 2. manifest 只需要保存少量信息

例如：

```json
{
  "format_version": 1,
  "app_version": "1.2.0",
  "database_version": 3,
  "created_at": "2026-08-06"
}
```

作用：

未来数据库升级。

例如：

当前：

```
database_version = 3
```

未来：

```
database_version = 5
```

导入时：

```
备份版本3

↓

migration

↓

版本5
```

---

# 3. Rust实现会非常简单

你的目录：

```
src-tauri/src/

backup/

├── mod.rs
├── export.rs
└── import.rs
```

---

## Export流程

```text
用户点击导出

↓

选择保存路径

↓

SQLite Backup

↓

生成临时sqlite

↓

写入zip

↓

.snapbackup
```

核心：

不要复制数据库：

```
copy(db)
```

使用：

```
VACUUM INTO
```

保证一致性。

---

## Import流程

```text
用户选择.snapbackup

↓

解压临时目录

↓

读取manifest

↓

检查版本

↓

关闭数据库连接

↓

替换数据库

↓

重新启动
```

---

# 4. 需要考虑一个关键问题：附件怎么办？

你的数据库里面可能有：

```sql
invoice

id
amount
date
file_path
ocr_text
```

例如：

```
file_path:

C:/Users/User/AppData/SnapClaim/image/001.png
```

如果只恢复数据库：

路径还存在吗？

所以数据库最好不要存绝对路径。

不要：

```text
C:\Users\xxx\SnapClaim\image\a.png
```

应该：

```text
attachments/a.png
```

或者：

```text
invoice_id + filename
```

即使未来删除附件，数据库仍然干净。

---

# 5. UI也可以更加轻量

设置：

```
数据管理

----------------

📦 导出数据

备份你的报销记录


📂 导入数据

恢复之前的数据


数据库大小:
12.5 MB

最后备份:
2026-08-06
```

---

# 6. 后续扩展空间

这个设计未来依然可以扩展：

## v1.3

当前：

```
SQLite Backup
```

↓

## v2.0

增加：

```
AES加密

.snapbackup
```

---

## 我认为 SnapClaim 当前最合适的最终方案

```
BackupService

       |
       |
       +-- Export

       |
       +-- Import


Export:

SQLite
  |
VACUUM INTO
  |
manifest.json
  |
zip
  |
.snapbackup


Import:

.snapbackup
  |
verify
  |
replace database
```