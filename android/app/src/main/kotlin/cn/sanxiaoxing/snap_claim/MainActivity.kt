package cn.sanxiaoxing.snap_claim

import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "snap_claim/shared_images"
        private const val REMINDER_CHANNEL = "snap_claim/reminders"
        private const val LAUNCHER_CHANNEL = "snap_claim/launcher"
        @Volatile private var activeReminderChannel: MethodChannel? = null

        fun notifyReminderChanged() {
            activeReminderChannel?.invokeMethod("changed", null)
        }
        private const val TAG = "SnapClaim"

        /// 冷启动时 Flutter 尚未就绪，分享图片路径先暂存于此，待 Dart 侧取走。
        @Volatile
        private var pendingImagePaths: List<String> = emptyList()
        private val pendingEntryUris = mutableListOf<String>()

    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val launcherChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL)
        launcherChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "takePendingEntries" -> {
                        result.success(pendingEntryUris.toList())
                        pendingEntryUris.clear()
                    }
                    "updateOwedWidget" -> {
                        LauncherIntegration.updateOwed(
                            this,
                            call.argument<String>("amount") ?: "¥0.00",
                            call.argument<Boolean>("positive") ?: false,
                        )
                        result.success(null)
                    }
                    "updateQuickWidget" -> {
                        LauncherIntegration.updateQuick(
                            this,
                            call.argument<List<Map<String, Any?>>>("items") ?: emptyList(),
                        )
                        result.success(null)
                    }
                    "setShortcuts" -> {
                        LauncherIntegration.setShortcuts(
                            this,
                            call.argument<List<Map<String, Any?>>>("items") ?: emptyList(),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("launcher_error", e.message, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart 启动时取走待处理的分享图片路径（取走即清空，避免重复处理）。
                "takePendingImages" -> {
                    result.success(pendingImagePaths)
                    pendingImagePaths = emptyList()
                }
                else -> result.notImplemented()
            }
        }
        val reminderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDER_CHANNEL)
        activeReminderChannel = reminderChannel
        reminderChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    ReminderNotifications.sync(this)
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
                        ReminderNotifications.pendingCount(this) > 0) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4107)
                    }
                    result.success(null)
                }
                "getTime" -> result.success(mapOf("hour" to ReminderNotifications.hour(this), "minute" to ReminderNotifications.minute(this)))
                "setTime" -> {
                    val hour = call.argument<Int>("hour")
                    val minute = call.argument<Int>("minute")
                    if (hour == null || minute == null || hour !in 0..23 || minute !in 0..59) {
                        result.error("invalid_time", "提醒时间无效", null)
                    } else {
                        ReminderNotifications.setTime(this, hour, minute)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        activeReminderChannel = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4107 && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            ReminderNotifications.sync(this)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        collectEntryAction(intent)
        super.onCreate(savedInstanceState)
        // 冷启动：分享 intent 在 onCreate 里即可取得。
        collectSharedImages(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        collectEntryAction(intent)
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, LAUNCHER_CHANNEL).invokeMethod("entriesChanged", null)
        }
        // 热启动：应用已在运行（launchMode=singleTop），走 onNewIntent。
        collectSharedImages(intent)
        // 引擎已就绪，直接推送给 Dart（takePendingImages 仅用于冷启动兜底）。
        val copied = pendingImagePaths
        if (copied.isNotEmpty()) {
            pendingImagePaths = emptyList()
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onSharedImages", copied)
            }
        }
    }

    private fun collectEntryAction(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme == "snapclaim" && uri.host == "entry") {
            pendingEntryUris.add(uri.toString())
        }
    }

    /// 从分享 intent 提取图片 URI，复制到应用缓存目录并记入待处理队列。
    /// 系统分享携带临时读权限，contentResolver 可直接读取，无需存储权限。
    private fun collectSharedImages(intent: Intent?) {
        if (intent == null) return
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND ->
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
            else -> return
        }
        // 部分分享器只写 ClipData 不写 EXTRA_STREAM，兜底读取。
        if (uris.isEmpty() && intent.clipData != null) {
            for (i in 0 until intent.clipData!!.itemCount) {
                intent.clipData!!.getItemAt(i).uri?.let { uris.add(it) }
            }
        }
        if (uris.isEmpty()) return

        val dir = File(cacheDir, "shared_images").apply { mkdirs() }
        val copied = uris.mapNotNull { uri ->
            try {
                val target = File(dir, "share_${System.currentTimeMillis()}_${uri.hashCode()}.img")
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
                target.absolutePath
            } catch (e: Exception) {
                Log.w(TAG, "复制分享图片失败: $e")
                null
            }
        }
        if (copied.isNotEmpty()) {
            pendingImagePaths = pendingImagePaths + copied
        }
    }
}
