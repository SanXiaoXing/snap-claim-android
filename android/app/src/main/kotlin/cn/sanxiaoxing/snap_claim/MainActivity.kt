package cn.sanxiaoxing.snap_claim

import android.content.Intent
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
        private const val TAG = "SnapClaim"

        /// 冷启动时 Flutter 尚未就绪，分享图片路径先暂存于此，待 Dart 侧取走。
        @Volatile
        private var pendingImagePaths: List<String> = emptyList()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 冷启动：分享 intent 在 onCreate 里即可取得。
        collectSharedImages(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
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
