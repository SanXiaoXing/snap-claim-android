package cn.sanxiaoxing.snap_claim

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// 公司欠我金额小组件 2×2。键名与 Dart 侧 HomeWidgets 字面量一致。
class OwedWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val amountText = widgetData.getString("owed_amount_text", null) ?: "¥0.00"
        val isPositive = widgetData.getBoolean("owed_is_positive", true)

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.owed_widget).apply {
                    setTextViewText(R.id.owed_amount, amountText)
                    setInt(
                        R.id.owed_container,
                        "setBackgroundResource",
                        if (isPositive) R.drawable.owed_bg_positive else R.drawable.owed_bg_settled,
                    )
                    setViewVisibility(
                        R.id.owed_status,
                        if (isPositive) View.GONE else View.VISIBLE,
                    )
                    setTextViewText(R.id.owed_status, "已结清")
                    val launch = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("snapclaim://entry/open_mine"),
                    )
                    setOnClickPendingIntent(R.id.owed_container, launch)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.w("SnapClaim", "金额小组件更新失败 widgetId=$widgetId", e)
            }
        }
    }
}
