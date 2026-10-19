package cn.sanxiaoxing.snap_claim

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build

/** Shared Android entry points for launcher widgets and dynamic shortcuts. */
object LauncherIntegration {
    // Keep the existing preference file so installed widgets retain their data after upgrading.
    fun widgetData(context: Context): SharedPreferences =
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

    fun launchIntent(context: Context, action: String): PendingIntent {
        val uri = Uri.parse(if (action.contains("://")) action else "snapclaim://entry/$action")
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = Intent.ACTION_VIEW
            data = uri
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            uri.toString().hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun updateOwed(context: Context, amount: String, positive: Boolean) {
        widgetData(context).edit()
            .putString("owed_amount_text", amount)
            .putBoolean("owed_is_positive", positive)
            .apply()
        updateWidget(context, OwedWidgetProvider::class.java)
    }

    fun updateQuick(context: Context, items: List<Map<String, Any?>>) {
        val edit = widgetData(context).edit()
        for (index in 0..1) {
            val item = items.getOrNull(index)
            edit.putBoolean("quick_${index}_visible", item != null)
            if (item != null) {
                edit.putString("quick_${index}_title", item["title"] as? String ?: "")
                edit.putString("quick_${index}_amount", item["amount"] as? String ?: "")
                edit.putString("quick_${index}_action", item["action"] as? String ?: "new_claim")
            }
        }
        edit.apply()
        updateWidget(context, QuickActionsWidgetProvider::class.java)
    }

    private fun updateWidget(context: Context, provider: Class<*>) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        when (provider) {
            OwedWidgetProvider::class.java -> OwedWidgetProvider().onUpdate(context, manager, ids)
            QuickActionsWidgetProvider::class.java -> QuickActionsWidgetProvider().onUpdate(context, manager, ids)
        }
    }

    fun setShortcuts(context: Context, items: List<Map<String, Any?>>) {
        if (Build.VERSION.SDK_INT < 25) return
        val manager = context.getSystemService(ShortcutManager::class.java)
        val shortcuts = items.map { item ->
            val action = item["action"] as String
            val icon = when (item["icon"] as? String) {
                "ic_shortcut_new" -> R.mipmap.ic_shortcut_new
                "ic_shortcut_claim" -> R.mipmap.ic_shortcut_claim
                else -> R.mipmap.ic_launcher
            }
            ShortcutInfo.Builder(context, action)
                .setShortLabel(item["title"] as String)
                .setIcon(Icon.createWithResource(context, icon))
                .setIntent(Intent(context, MainActivity::class.java).apply {
                    this.action = Intent.ACTION_VIEW
                    data = Uri.parse("snapclaim://entry/${Uri.encode(action)}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                })
                .build()
        }
        check(manager.setDynamicShortcuts(shortcuts)) { "无法更新长按快捷方式" }
    }
}
