package cn.sanxiaoxing.snap_claim

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Native alarms keep working while Flutter is closed. The database remains the source of truth. */
object ReminderNotifications {
    private const val PREFS = "claim_reminders"
    private const val CHANNEL = "claim_deadlines"
    private const val ACTION_ALARM = "cn.sanxiaoxing.snap_claim.DEADLINE_ALARM"
    private const val ACTION_SUBMIT = "cn.sanxiaoxing.snap_claim.SUBMIT_FINANCE"

    fun hour(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("hour", 10)
    fun minute(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("minute", 0)

    fun setTime(context: Context, hour: Int, minute: Int) {
        require(hour in 0..23 && minute in 0..59)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt("hour", hour).putInt("minute", minute).apply()
        sync(context)
    }

    fun pendingCount(context: Context): Int = readClaims(context).count { !it.archived && !it.submitted }

    fun sync(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        val claims = readClaims(context)
        val activeIds = claims.filter { !it.archived && !it.submitted }.map { it.id }.toSet()
        val oldIds = prefs.getStringSet("scheduled_ids", emptySet()) ?: emptySet()
        for (id in oldIds) {
            alarmManager.cancel(alarmIntent(context, id))
            if (id !in activeIds) notificationManager.cancel(notificationId(id))
        }
        prefs.edit().putStringSet("scheduled_ids", activeIds).apply()

        val now = System.currentTimeMillis()
        for (claim in claims) {
            if (claim.id !in activeIds) continue
            val key = "notified_${claim.id}_${claim.endDate}"
            if (prefs.getBoolean(key, false)) continue
            val trigger = reminderAt(context, claim.endDate)
            if (trigger <= now) {
                post(context, claim)
            } else {
                // Inexact alarms work without special alarm permission. Android may defer delivery slightly.
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, alarmIntent(context, claim.id))
            }
        }
    }

    fun onAlarm(context: Context, id: String) {
        val claim = readClaims(context).firstOrNull { it.id == id } ?: return
        if (!claim.archived && !claim.submitted && reminderAt(context, claim.endDate) <= System.currentTimeMillis()) {
            post(context, claim)
        }
    }

    fun submit(context: Context, id: String) {
        val file = context.getDatabasePath("snap_claim.db")
        if (!file.exists()) return
        SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
            db.execSQL("UPDATE claims SET submitted_to_finance = 1 WHERE id = ? AND archived = 0", arrayOf(id))
        }
        context.getSystemService(NotificationManager::class.java).cancel(notificationId(id))
        sync(context)
        MainActivity.notifyReminderChanged()
    }

    private fun readClaims(context: Context): List<ClaimRow> {
        val file = context.getDatabasePath("snap_claim.db")
        if (!file.exists()) return emptyList()
        return try {
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                db.rawQuery("SELECT id, name, end_date, archived, submitted_to_finance FROM claims", null).use { cursor ->
                    buildList {
                        while (cursor.moveToNext()) {
                            add(ClaimRow(cursor.getString(0), cursor.getString(1), cursor.getLong(2), cursor.getInt(3) != 0, cursor.getInt(4) != 0))
                        }
                    }
                }
            }
        } catch (_: Exception) {
            // A pre-v4 backup may be replaced while the app is upgrading it.
            emptyList()
        }
    }

    private fun reminderAt(context: Context, endDate: Long): Long {
        val calendar = Calendar.getInstance().apply {
            timeInMillis = endDate
            set(Calendar.HOUR_OF_DAY, hour(context))
            set(Calendar.MINUTE, minute(context))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, 23)
        }
        return calendar.timeInMillis
    }

    private fun deadlineAt(endDate: Long): Long = Calendar.getInstance().apply {
        timeInMillis = endDate
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        add(Calendar.DAY_OF_YEAR, 30)
    }.timeInMillis

    private fun post(context: Context, claim: ClaimRow) {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val key = "notified_${claim.id}_${claim.endDate}"
        if (prefs.getBoolean(key, false)) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "报销期限提醒", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val deadline = deadlineAt(claim.endDate)
        val date = SimpleDateFormat("M月d日", Locale.CHINA).format(deadline)
        val nextDay = Calendar.getInstance().apply {
            timeInMillis = deadline
            add(Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
        val body = if (System.currentTimeMillis() >= nextDay) {
            "已超过 $date 截止日。完成签字并提交财务后，可直接标记待打款。"
        } else {
            "$date 截止（含当天）。完成签字并提交财务后，可直接标记待打款。"
        }
        val open = PendingIntent.getActivity(context, notificationId(claim.id), Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val submit = PendingIntent.getBroadcast(context, notificationId(claim.id), Intent(context, ReminderReceiver::class.java).apply {
            action = ACTION_SUBMIT
            data = Uri.parse("snapclaim://submit/${Uri.encode(claim.id)}")
            putExtra("claim_id", claim.id)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val notification = builder
            .setSmallIcon(R.drawable.ic_claim_notification)
            .setContentTitle("${claim.name} · 报销期限提醒")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .addAction(Notification.Action.Builder(null, "已提交财务", submit).build())
            .build()
        manager.notify(notificationId(claim.id), notification)
        prefs.edit().putBoolean(key, true).apply()
    }

    private fun alarmIntent(context: Context, id: String): PendingIntent = PendingIntent.getBroadcast(
        context, notificationId(id), Intent(context, ReminderReceiver::class.java).apply {
            action = ACTION_ALARM
            data = Uri.parse("snapclaim://alarm/${Uri.encode(id)}")
            putExtra("claim_id", id)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    private fun notificationId(id: String) = id.hashCode() and 0x7fffffff

    private data class ClaimRow(val id: String, val name: String, val endDate: Long, val archived: Boolean, val submitted: Boolean)
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("claim_id") ?: return
        when (intent.action) {
            "cn.sanxiaoxing.snap_claim.DEADLINE_ALARM" -> ReminderNotifications.onAlarm(context, id)
            "cn.sanxiaoxing.snap_claim.SUBMIT_FINANCE" -> ReminderNotifications.submit(context, id)
        }
    }
}

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_TIME_CHANGED || intent.action == Intent.ACTION_TIMEZONE_CHANGED) {
            ReminderNotifications.sync(context)
        }
    }
}
