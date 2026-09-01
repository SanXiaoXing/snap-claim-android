// 全局主题配置。
import 'package:flutter/material.dart';

/// 自定义色彩令牌，通过 ThemeExtension 挂载到 ThemeData，
/// 对应原型设计中的 CSS 变量（浅色/深色两套）。
@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  final Color bg;
  final Color bgSecondary;
  final Color card;
  final Color border;
  final Color fg;
  final Color fgMuted;
  final Color fgSoft;
  final Color accent;
  final Color accentLight;
  final Color accentBg;
  final Color danger;
  final Color dangerBg;

  const AppColorScheme({
    required this.bg,
    required this.bgSecondary,
    required this.card,
    required this.border,
    required this.fg,
    required this.fgMuted,
    required this.fgSoft,
    required this.accent,
    required this.accentLight,
    required this.accentBg,
    required this.danger,
    required this.dangerBg,
  });

  static const light = AppColorScheme(
    bg: Color(0xFFFFFFFF),
    bgSecondary: Color(0xFFF8FAFC),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    fg: Color(0xFF0F172A),
    fgMuted: Color(0xFF64748B),
    fgSoft: Color(0xFF94A3B8),
    accent: Color(0xFF10B981),
    accentLight: Color(0xFF34D399),
    accentBg: Color(0xFFECFDF5),
    danger: Color(0xFFEF4444),
    dangerBg: Color(0xFFFEF2F2),
  );

  static const dark = AppColorScheme(
    bg: Color(0xFF141210),
    bgSecondary: Color(0xFF1D1B17),
    card: Color(0xFF1D1B17),
    border: Color(0xFF2E2B25),
    fg: Color(0xFFEEEAE1),
    fgMuted: Color(0xFFA8A194),
    fgSoft: Color(0xFF7C766B),
    accent: Color(0xFF2EB98A),
    accentLight: Color(0xFF45C99C),
    accentBg: Color(0xFF0F2B20),
    danger: Color(0xFFE08B80),
    dangerBg: Color(0xFF3A1B16),
  );

  @override
  AppColorScheme copyWith({
    Color? bg,
    Color? bgSecondary,
    Color? card,
    Color? border,
    Color? fg,
    Color? fgMuted,
    Color? fgSoft,
    Color? accent,
    Color? accentLight,
    Color? accentBg,
    Color? danger,
    Color? dangerBg,
  }) {
    return AppColorScheme(
      bg: bg ?? this.bg,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      card: card ?? this.card,
      border: border ?? this.border,
      fg: fg ?? this.fg,
      fgMuted: fgMuted ?? this.fgMuted,
      fgSoft: fgSoft ?? this.fgSoft,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentBg: accentBg ?? this.accentBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
    );
  }

  @override
  AppColorScheme lerp(AppColorScheme? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      bg: Color.lerp(bg, other.bg, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      fgMuted: Color.lerp(fgMuted, other.fgMuted, t)!,
      fgSoft: Color.lerp(fgSoft, other.fgSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentBg: Color.lerp(accentBg, other.accentBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
    );
  }
}

extension AppColorSchemeX on BuildContext {
  AppColorScheme get colors =>
      Theme.of(this).extension<AppColorScheme>() ?? AppColorScheme.light;
}

ThemeData buildLightTheme() {
  const c = AppColorScheme.light;
  return _baseTheme(c, Brightness.light);
}

ThemeData buildDarkTheme() {
  const c = AppColorScheme.dark;
  return _baseTheme(c, Brightness.dark);
}

ThemeData _baseTheme(AppColorScheme c, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = isDark ? Typography().white : Typography().black;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    cardColor: c.card,
    dividerColor: c.border,
    splashFactory: InkSparkle.splashFactory,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: Colors.white,
      secondary: c.accentLight,
      onSecondary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.card,
      onSurface: c.fg,
    ),
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    iconTheme: IconThemeData(color: c.fg, size: 22),
    textTheme: base.merge(_textTheme(base, c)),
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: c.border),
      ),
    ),
  );
}

TextTheme _textTheme(TextTheme base, AppColorScheme c) {
  return base.copyWith(
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: c.fg,
      letterSpacing: -0.02,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: c.fg,
    ),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, color: c.fg),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 13, color: c.fg),
    bodySmall: base.bodySmall?.copyWith(fontSize: 12, color: c.fgMuted),
    labelSmall: base.labelSmall?.copyWith(fontSize: 11, color: c.fgMuted),
  );
}

/// 通用卡片装饰：卡片底色 + 圆角 + 细边框。
BoxDecoration cardDecoration(AppColorScheme c) => BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.border),
    );

/// 全局统一的浮动 SnackBar 提示。
void showAppSnack(
  BuildContext context,
  String msg, {
  Color? background,
  int ms = 1400,
}) {
  final c = context.colors;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: background ?? c.fg,
      duration: Duration(milliseconds: ms),
    ),
  );
}

/// 统一对话框骨架：卡片底色 + 圆角 + 标题样式，供各页弹窗复用。
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final MainAxisAlignment? actionsAlignment;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.actionsAlignment,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: c.fg,
        ),
      ),
      content: content,
      actions: actions,
      actionsAlignment: actionsAlignment,
    );
  }
}

/// 对话框中的文本按钮（取消 / 关闭等），统一样式。
Widget appDialogButton(
  BuildContext context, {
  String label = '取消',
  VoidCallback? onPressed,
}) {
  final c = context.colors;
  return TextButton(
    onPressed: onPressed ?? () => Navigator.of(context).pop(),
    child: Text(label, style: TextStyle(fontSize: 14, color: c.fgMuted)),
  );
}
