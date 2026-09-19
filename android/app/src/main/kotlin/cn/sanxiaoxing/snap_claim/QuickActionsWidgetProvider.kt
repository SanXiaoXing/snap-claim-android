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

/// 快捷操作小组件 2×2：prefs 索引 0 → row0 最近单据，索引 1 → row2 新建。
class QuickActionsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.quick_actions_widget).apply {
                    bindRow(
                        context = context,
                        containerId = R.id.quick_row0,
                        titleId = R.id.quick_row0_title,
                        amountId = R.id.quick_row0_amount,
                        index = 0,
                        defaultTitle = "",
                        widgetData = widgetData,
                    )
                    bindRow(
                        context = context,
                        containerId = R.id.quick_row2,
                        titleId = R.id.quick_row2_title,
                        amountId = R.id.quick_row2_amount,
                        index = 1,
                        defaultTitle = "新建报销单",
                        widgetData = widgetData,
                    )
                    val claimVisible = visibleFor(widgetData, 0)
                    val newVisible = visibleFor(widgetData, 1)
                    if (!claimVisible && !newVisible) {
                        showNewClaimOnly(context, this)
                    }
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.w("SnapClaim", "快捷操作小组件更新失败 widgetId=$widgetId", e)
                try {
                    val fallback = RemoteViews(context.packageName, R.layout.quick_actions_widget)
                    showNewClaimOnly(context, fallback)
                    appWidgetManager.updateAppWidget(widgetId, fallback)
                } catch (e2: Exception) {
                    Log.e("SnapClaim", "快捷操作小组件降级渲染仍失败", e2)
                }
            }
        }
    }

    private fun visibleFor(widgetData: SharedPreferences, index: Int): Boolean {
        val key = "quick_${index}_visible"
        return if (widgetData.contains(key)) widgetData.getBoolean(key, false) else index == 1
    }

    private fun RemoteViews.bindRow(
        context: Context,
        containerId: Int,
        titleId: Int,
        amountId: Int,
        index: Int,
        defaultTitle: String,
        widgetData: SharedPreferences,
    ) {
        val visible = visibleFor(widgetData, index)
        setViewVisibility(containerId, if (visible) View.VISIBLE else View.GONE)
        if (!visible) return
        val title = widgetData.getString("quick_${index}_title", null) ?: defaultTitle
        val amount = widgetData.getString("quick_${index}_amount", null) ?: ""
        val action = widgetData.getString("quick_${index}_action", null)
            ?: "snapclaim://entry/new_claim"
        setTextViewText(titleId, title)
        if (amount.isEmpty()) {
            setViewVisibility(amountId, View.GONE)
        } else {
            setViewVisibility(amountId, View.VISIBLE)
            setTextViewText(amountId, amount)
        }
        val uri = if (action.contains("://")) {
            Uri.parse(action)
        } else {
            Uri.parse("snapclaim://entry/$action")
        }
        val launch = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
        setOnClickPendingIntent(containerId, launch)
    }

    private fun showNewClaimOnly(context: Context, views: RemoteViews) {
        views.apply {
            setViewVisibility(R.id.quick_row0, View.GONE)
            setViewVisibility(R.id.quick_row2, View.VISIBLE)
            setTextViewText(R.id.quick_row2_title, "新建报销单")
            setViewVisibility(R.id.quick_row2_amount, View.GONE)
            val launch = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("snapclaim://entry/new_claim"),
            )
            setOnClickPendingIntent(R.id.quick_row2, launch)
        }
    }
}
