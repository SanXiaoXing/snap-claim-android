package cn.sanxiaoxing.snapclaim.plugin

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import kotlin.math.abs

@InvokeArg
class RecognizeArgs {
    lateinit var uri: String
}

@TauriPlugin
class MlkitTextPlugin(private val activity: Activity) : Plugin(activity) {

    private val recognizer by lazy {
        TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    }

    @Command
    fun recognize(invoke: Invoke) {
        val args = invoke.parseArgs(RecognizeArgs::class.java)
        val bitmap = try {
            decodeBitmap(Uri.parse(args.uri))
        } catch (e: Exception) {
            invoke.reject("decode image failed: ${e.message}")
            return
        }

        recognizer.process(InputImage.fromBitmap(bitmap, 0))
            .addOnSuccessListener { result ->
                val ret = JSObject()
                ret.put("text", toReadingOrderedText(result))
                invoke.resolve(ret)
            }
            .addOnFailureListener { e ->
                invoke.reject("ML Kit failed: ${e.message}")
            }
    }

    /// content:// URI → software Bitmap (ML Kit rejects hardware bitmaps).
    private fun decodeBitmap(uri: Uri): Bitmap {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val source = ImageDecoder.createSource(activity.contentResolver, uri)
            ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        } else {
            @Suppress("DEPRECATION")
            MediaStore.Images.Media.getBitmap(activity.contentResolver, uri)
        }
    }

    /// Flatten blocks→lines, sort into reading order, join with \n.
    /// ML Kit does NOT guarantee reading order — same fix as desktop §9.3.
    private fun toReadingOrderedText(result: Text): String {
        val lines = result.textBlocks.flatMap { it.lines }
        val sorted = lines.sortedWith { a, b ->
            val aTop = a.boundingBox?.top ?: 0
            val bTop = b.boundingBox?.top ?: 0
            if (abs(aTop - bTop) < 10) {
                (a.boundingBox?.left ?: 0) - (b.boundingBox?.left ?: 0)
            } else {
                aTop - bTop
            }
        }
        return sorted.joinToString("\n") { it.text }
    }
}
