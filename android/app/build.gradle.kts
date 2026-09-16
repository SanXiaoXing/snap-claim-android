import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// release 签名配置：本地优先读取 android/key.properties（已 gitignore、不入库），
// CI 由 GitHub Secrets 写入该文件；Windows / macOS / CI 三处共用同一把密钥，
// 保证所有环境构建的 release APK 签名一致，可互相覆盖升级。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingProp(name: String, envName: String): String? =
    (keystoreProperties[name] as String?)?.takeIf { it.isNotBlank() }
        ?: System.getenv(envName)?.takeIf { it.isNotBlank() }

android {
    namespace = "cn.sanxiaoxing.snap_claim"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cn.sanxiaoxing.snap_claim"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFileValue = signingProp("storeFile", "KEYSTORE_FILE")
            if (storeFileValue != null) storeFile = file(storeFileValue)
            keyAlias = signingProp("keyAlias", "KEY_ALIAS")
            keyPassword = signingProp("keyPassword", "KEY_PASSWORD")
            storePassword = signingProp("storePassword", "KEYSTORE_PASSWORD")
        }
    }

    buildTypes {
        release {
            // 正式签名：同一把密钥在 Windows / macOS / CI 三处复用，保证 APK 签名一致、可互相覆盖升级。
            // 仅当本机未配置 key.properties（或未注入环境变量）时退回 debug 签名，便于本地快速调试。
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig = if (releaseSigning.storeFile != null && !releaseSigning.keyAlias.isNullOrEmpty()) {
                releaseSigning
            } else {
                println("WARNING: 未检测到 release 签名配置（key.properties / 环境变量），" +
                    "本包将使用 debug 签名，无法与其他机器构建的 APK 互相覆盖安装！")
                signingConfigs.getByName("debug")
            }
            // 显式应用 ProGuard 规则：ML Kit 语言模型类为 compileOnly 依赖，
            // 需 dontwarn 抑制 R8 缺失类报错（见 proguard-rules.pro）。
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // APK 输出命名：SnapClaim_<versionName>[_<abi>].apk（--split-per-abi 时带 ABI 后缀）。
    // 注：Flutter 插件会把产物复制到 flutter-apk 目录并命名为 app-<abi>-release.apk，
    // 同时 flutter 工具构建结束后按该名字检查产物；因此这里在插件复制完成后
    // 额外生成 SnapClaim_ 命名的交付副本，保留原 app-* 文件以满足 flutter 检查。
    applicationVariants.all {
        val assembleTask = assembleProvider.get()
        assembleTask.doLast {
            val apkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
            if (!apkDir.isDirectory) return@doLast
            // 仅处理 release 产物（app-<abi>-release.apk），忽略 debug / profile 与 sha1。
            apkDir.listFiles { f ->
                f.isFile &&
                    f.name.startsWith("app-") &&
                    f.name.endsWith("-release.apk")
            }?.forEach { f ->
                val abi = f.name
                    .removePrefix("app-")
                    .removeSuffix("-release.apk")
                val targetName =
                    "SnapClaim_${versionName}${abi.takeIf { it.isNotEmpty() }?.let { "_$it" } ?: ""}.apk"
                if (f.name != targetName) {
                    f.copyTo(File(apkDir, targetName), overwrite = true)
                }
            }
        }
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val abi = output.getFilter(com.android.build.OutputFile.ABI)
            output.outputFileName = "SnapClaim_${versionName}${abi?.let { "_$it" } ?: ""}.apk"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ML Kit 文字识别默认仅含拉丁脚本；中文识别需手动加 chinese 语言包，
    // 否则 TextRecognizer(script: chinese) 运行时实例化 ChineseTextRecognizerOptions
    // 会因类定义不在 APK 而 NoClassDefFoundError，导致 OCR 闪退。
    // 详见 https://pub.dev/packages/google_mlkit_text_recognition#adding-language-package-dependencies
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}
