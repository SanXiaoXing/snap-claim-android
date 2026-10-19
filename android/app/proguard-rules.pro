# SnapClaim 的 ProGuard/R8 规则。
# ML Kit 中文识别器类由 android/app/build.gradle.kts 的
# implementation 'com.google.mlkit:text-recognition-chinese' 提供（非 Play 服务）。
# 其他语言包未引入，只抑制这些可选类的缺失告警。
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# 桌面小组件 Provider 必须保留原始类名：Manifest 引用。
# R8 裁剪/改名会导致 MIUI「载入窗口小部件时出现问题」。
-keep class cn.sanxiaoxing.snap_claim.OwedWidgetProvider { *; }
-keep class cn.sanxiaoxing.snap_claim.QuickActionsWidgetProvider { *; }
-keep class cn.sanxiaoxing.snap_claim.MainActivity { *; }

