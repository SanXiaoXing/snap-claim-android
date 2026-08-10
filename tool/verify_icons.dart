// 校验生成的图标 PNG：头部签名、尺寸与文件大小。
// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final paths = [
    'assets/icon/favicon.png',
    'web/favicon.png',
    'web/icons/Icon-192.png',
    'web/icons/Icon-512.png',
    'web/icons/Icon-maskable-192.png',
    'web/icons/Icon-maskable-512.png',
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    'assets/icon/preview_adaptive.png',
    'assets/icon/preview_adaptive_round.png',
  ];
  var fail = 0;
  for (final p in paths) {
    final f = File(p);
    if (!f.existsSync()) {
      print('MISS $p');
      fail++;
      continue;
    }
    final bytes = f.readAsBytesSync();
    final sigOk = bytes.length > 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        String.fromCharCodes(bytes.sublist(12, 16)) == 'IHDR';
    final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    if (!sigOk || w != h) {
      print('BAD  $p ${sigOk ? '' : 'sig'} ${w}x$h ${bytes.length}B');
      fail++;
    } else {
      print('OK   $p ${w}x$h ${bytes.length}B');
    }
  }
  print(fail == 0 ? 'all valid' : '$fail FAILED');
  exit(fail == 0 ? 0 : 1);
}
