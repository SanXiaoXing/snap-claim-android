// 应用图标像素画生成脚本（纯 Dart，无外部依赖）。
// 依据参考图绘制：紫龙（紫红身体）戴红帽（黄色饰带），白色大圆眼 + 微笑，
// 手持黄色方框（白面 + 绿色向上箭头），黑色背景。
// 用法: dart run tool/generate_icon.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

// ---------- 像素画布 ----------
class Canvas {
  final int w, h;
  final List<Uint32List> px; // 每像素 ARGB

  Canvas(this.w, this.h) : px = List.generate(h, (_) => Uint32List(w));

  void set(int x, int y, int argb) {
    if (x >= 0 && x < w && y >= 0 && y < h) px[y][x] = argb;
  }

  void fillRect(int x, int y, int w, int h, int argb) {
    for (var yy = y; yy < y + h; yy++) {
      for (var xx = x; xx < x + w; xx++) {
        set(xx, yy, argb);
      }
    }
  }

  /// 实心椭圆（含边界），cx/cy 为圆心，rx/ry 为半径。
  void fillEllipse(int cx, int cy, double rx, double ry, int argb) {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        if (dx * dx + dy * dy <= 1.0) set(x, y, argb);
      }
    }
  }

  /// 微笑弧线：抛物线 y = baseY - curve * (x - cx)^2。
  void smile(int cx, int baseY, int xFrom, int xTo, double curve, int argb) {
    for (var x = xFrom; x <= xTo; x++) {
      final dy = (curve * (x - cx) * (x - cx)).round();
      set(x, baseY - dy, argb);
    }
  }

  /// 将内容整体下移 n 行（顶部补黑），用于垂直居中。
  void shiftDown(int n) {
    for (var y = h - 1; y >= 0; y--) {
      for (var x = 0; x < w; x++) {
        px[y][x] = y >= n ? px[y - n][x] : kBlack;
      }
    }
  }

  /// 最近邻缩放。
  Uint8List scaleTo(int dw, int dh) {
    final out = Uint8List(dw * dh * 4);
    for (var y = 0; y < dh; y++) {
      final sy = (y * h ~/ dh);
      for (var x = 0; x < dw; x++) {
        final sx = (x * w ~/ dw);
        final a = px[sy][sx];
        final i = (y * dw + x) * 4;
        out[i] = (a >> 16) & 0xFF;
        out[i + 1] = (a >> 8) & 0xFF;
        out[i + 2] = a & 0xFF;
        out[i + 3] = (a >> 24) & 0xFF;
      }
    }
    return out;
  }

  /// 控制台 ASCII 预览（调试用）。
  void preview() {
    const ramp = '@%#*+=-:. ';
    for (var y = 0; y < h; y++) {
      final buf = StringBuffer();
      for (var x = 0; x < w; x++) {
        final a = px[y][x];
        if (a == 0xFF000000) {
          buf.write(' ');
        } else if ((a >> 24) & 0xFF < 128) {
          buf.write('.');
        } else {
          final r = (a >> 16) & 0xFF;
          final g = (a >> 8) & 0xFF;
          final b = a & 0xFF;
          final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
          // 白色（亮度极高）单独用 W 表示，避免与背景空格混淆。
          buf.write(lum > 230 ? 'W' : ramp[lum * ramp.length ~/ 256]);
        }
      }
      print(buf.toString());
    }
  }
}

// ---------- 调色板 ----------
const kBlack = 0xFF000000;
const kPurpleDark = 0xFF6D28D9; // 描边/暗部
const kPurple = 0xFF8B5CF6; // 主体
const kPurpleLight = 0xFFA78BFA; // 高光
const kRed = 0xFFEF4444; // 帽
const kRedDark = 0xFFB91C1C;
const kRedLight = 0xFFFCA5A5;
const kYellow = 0xFFFACC15; // 帽饰带/盒框
const kYellowDark = 0xFFCA8A04;
const kWhite = 0xFFFFFFFF;
const kGray = 0xFF9CA3AF; // 鳞片/岩石
const kGrayDark = 0xFF6B7280;
const kGreen = 0xFF22C55E; // 箭头
const kGreenDark = 0xFF16A34A;
const kEyeDark = 0xFF3B0764; // 瞳孔

// ---------- 绘制 ----------
Canvas drawIcon() {
  const n = 40;
  final c = Canvas(n, n);
  // 背景纯黑。
  c.fillRect(0, 0, n, n, kBlack);

  // --- 帽（红，顶部圆顶 + 檐，黄色饰带）---
  c.fillEllipse(20, 5, 9, 5.2, kRed); // 圆顶
  c.fillRect(10, 7, 20, 2, kYellow); // 黄色饰带
  c.fillRect(8, 9, 24, 2, kRed); // 帽檐
  c.fillRect(8, 10, 24, 1, kRedDark); // 檐下暗边
  // 帽顶火焰状像素块（黄/白小点）。
  c.set(19, 1, kYellow);
  c.set(21, 1, kYellow);
  c.set(20, 0, kWhite);
  c.set(15, 2, kRedLight);
  c.set(25, 2, kRedLight);

  // --- 头（紫，大圆）---
  c.fillEllipse(20, 16, 11.5, 8.5, kPurple); // 头部
  c.fillEllipse(15, 12, 3.5, 3, kPurpleLight); // 左上高光
  // 头部两侧灰色鳞片/岩石块。
  c.fillRect(7, 14, 3, 5, kGrayDark);
  c.fillRect(30, 14, 3, 5, kGrayDark);
  c.fillRect(8, 15, 2, 3, kGray);
  c.fillRect(30, 15, 2, 3, kGray);

  // --- 眼（白色大圆 + 深色瞳孔）---
  c.fillEllipse(18, 15, 4.2, 4.2, kWhite);
  c.fillEllipse(18, 16, 1.8, 2.2, kEyeDark);
  c.set(17, 14, kWhite); // 高光点

  // --- 微笑 ---
  c.smile(18, 21, 12, 24, 0.09, kPurpleDark);

  // --- 身体（紫）---
  c.fillRect(11, 21, 18, 10, kPurple);
  c.fillRect(11, 29, 18, 2, kPurpleDark); // 底部暗边
  // 身体两侧灰色鳞片。
  c.fillRect(9, 24, 3, 4, kGrayDark);
  c.fillRect(28, 24, 3, 4, kGrayDark);
  c.fillRect(10, 25, 2, 2, kGray);

  // --- 手臂（紫，伸向盒子两侧）---
  c.fillRect(8, 25, 5, 3, kPurple);
  c.fillRect(27, 25, 5, 3, kPurple);

  // --- 盒子（黄框 + 白面 + 绿色向上箭头）---
  c.fillRect(13, 22, 14, 12, kYellow); // 外框
  c.fillRect(13, 22, 14, 2, kYellowDark); // 顶部暗边
  c.fillRect(13, 22, 2, 12, kYellowDark); // 左侧暗边
  c.fillRect(15, 24, 10, 8, kWhite); // 白色正面
  // 绿色向上箭头：箭头顶 + 箭杆。
  c.fillRect(18, 25, 4, 2, kGreen); // 头顶
  c.fillRect(19, 27, 2, 4, kGreen); // 箭杆
  c.fillRect(18, 25, 4, 1, kGreenDark); // 头顶暗边
  // 盒子下沿暗边。
  c.fillRect(13, 32, 14, 2, kYellowDark);

  return c;
}

// ---------- PNG 编码（zlib + CRC32） ----------
final Uint32List _crcTable = Uint32List(256);
void _initCrc() {
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    _crcTable[n] = c;
  }
}

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

void _chunk(List<int> out, String type, List<int> data) {
  final len = data.length;
  out.addAll([
    (len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF
  ]);
  final typeBytes = utf8.encode(type);
  out.addAll(typeBytes);
  out.addAll(data);
  final crc = _crc32([...typeBytes, ...data]);
  out.addAll([
    (crc >> 24) & 0xFF, (crc >> 16) & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF
  ]);
}

Uint8List encodePng(Uint8List rgba, int w, int h) {
  _initCrc();
  final out = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG 签名
  ];
  // IHDR
  final ihdr = <int>[
    (w >> 24) & 0xFF, (w >> 16) & 0xFF, (w >> 8) & 0xFF, w & 0xFF,
    (h >> 24) & 0xFF, (h >> 16) & 0xFF, (h >> 8) & 0xFF, h & 0xFF,
    8, // bit depth
    6, // color type RGBA
    0, 0, 0, // compression, filter, interlace
  ];
  _chunk(out, 'IHDR', ihdr);
  // IDAT: 每行前置 filter byte 0，zlib 压缩。
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    raw.add(rgba.sublist(y * w * 4, (y + 1) * w * 4));
  }
  final compressed = zlibEncode(raw.toBytes());
  _chunk(out, 'IDAT', compressed);
  _chunk(out, 'IEND', []);
  return Uint8List.fromList(out);
}

// dart:io 的 zlib 编解码（无外部依赖）。
List<int> zlibEncode(List<int> data) {
  return ZLibCodec(level: 9).encode(data);
}

// ---------- 输出 ----------
void writePng(String path, Canvas src, int size) {
  final scaled = src.scaleTo(size, size);
  final png = encodePng(scaled, size, size);
  File(path).writeAsBytesSync(png);
  print('write $path (${size}x$size, ${png.length} bytes)');
}

void main() {
  final icon = drawIcon();
  // 角色内容纵跨约 y=0..33，整体下移 3 像素使图标垂直居中。
  icon.shiftDown(3);
  icon.preview();

  // 应用内品牌图标（分享卡片 Logo 用）。
  writePng('assets/icon/favicon.png', icon, 512);

  // Web 图标。
  writePng('web/favicon.png', icon, 128);
  writePng('web/icons/Icon-192.png', icon, 192);
  writePng('web/icons/Icon-maskable-192.png', icon, 192);
  writePng('web/icons/Icon-512.png', icon, 512);
  writePng('web/icons/Icon-maskable-512.png', icon, 512);

  // Android 启动图标（mipmap 各密度）。
  writePng('android/app/src/main/res/mipmap-mdpi/ic_launcher.png', icon, 48);
  writePng('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', icon, 72);
  writePng('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', icon, 96);
  writePng('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', icon, 144);
  writePng('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', icon, 192);

  // 自适应图标预览（资源目录已有同名文件，一并更新保持图标一致）。
  writePng('assets/icon/preview_adaptive.png', icon, 512);
  writePng('assets/icon/preview_adaptive_round.png', icon, 512);

  print('done');
}
