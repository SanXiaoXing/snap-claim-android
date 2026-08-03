# SnapClaim 的 ProGuard/R8 规则。
# ML Kit 中文识别器类由 android/app/build.gradle.kts 的
# implementation 'com.google.mlkit:text-recognition-chinese' 提供（非 Play 服务）。
# 以下 dontwarn 作为安全网：若未来移除该依赖，R8 缺失类告警被抑制而不致构建失败，
# 但运行时仍会 NoClassDefFoundError——正确做法是保留上述 implementation 依赖。
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# 保留 ML Kit 主体类，避免混淆导致运行时问题。
-keep class com.google.mlkit.** { *; }
