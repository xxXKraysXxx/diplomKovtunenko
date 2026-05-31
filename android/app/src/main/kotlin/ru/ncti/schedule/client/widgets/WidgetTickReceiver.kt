package ru.ncti.schedule.client.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

/// Broadcast receiver driving the minute-level "осталось N мин" counter in
/// the current-lesson + today widgets. AppWidget's own updatePeriodMillis
/// has a 30-minute floor, which is too coarse for a live countdown, so we
/// chain one-shot AlarmManager.set() calls: each firing re-renders any
/// installed widgets from the SharedPreferences snapshot and schedules the
/// next tick ~60s out. The countdown itself is computed Kotlin-side from
/// absolute epoch timestamps the Flutter side writes, so it stays fresh
/// even when Dart hasn't run in a while.
class WidgetTickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WidgetDiagnostic.log(context, "WidgetTicker", "tick action=${intent.action}")
        try {
            tickAll(context)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "WidgetTicker", "tick FAILED", t)
        }
        if (hasAnyWidget(context)) {
            scheduleNext(context)
        }
    }

    companion object {
        const val ACTION_TICK = "ru.ncti.schedule.client.widgets.TICK"
        private const val INTERVAL_MS = 60_000L

        fun scheduleNext(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val pi = pendingIntent(context)
            try {
                am.set(
                    AlarmManager.RTC,
                    System.currentTimeMillis() + INTERVAL_MS,
                    pi,
                )
            } catch (t: Throwable) {
                WidgetDiagnostic.log(context, "WidgetTicker", "scheduleNext FAILED", t)
            }
        }

        fun ensureScheduled(context: Context) {
            if (hasAnyWidget(context)) scheduleNext(context)
        }

        fun cancelIfIdle(context: Context) {
            if (!hasAnyWidget(context)) {
                val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                    ?: return
                am.cancel(pendingIntent(context))
            }
        }

        private fun pendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, WidgetTickReceiver::class.java).apply {
                action = ACTION_TICK
            }
            return PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun hasAnyWidget(context: Context): Boolean {
            val mgr = AppWidgetManager.getInstance(context)
            val providers = arrayOf(
                CurrentLessonWidgetProvider::class.java,
                TodayScheduleWidgetProvider::class.java,
                WeekSummaryWidgetProvider::class.java,
            )
            for (cls in providers) {
                val ids = mgr.getAppWidgetIds(ComponentName(context, cls))
                if (ids.isNotEmpty()) return true
            }
            return false
        }

        private fun tickAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val data = HomeWidgetPlugin.getData(context)

            val currentIds = mgr.getAppWidgetIds(
                ComponentName(context, CurrentLessonWidgetProvider::class.java)
            )
            if (currentIds.isNotEmpty()) {
                CurrentLessonWidgetProvider().onUpdate(context, mgr, currentIds, data)
            }
            val todayIds = mgr.getAppWidgetIds(
                ComponentName(context, TodayScheduleWidgetProvider::class.java)
            )
            if (todayIds.isNotEmpty()) {
                TodayScheduleWidgetProvider().onUpdate(context, mgr, todayIds, data)
            }
            // Week widget has no live counter; skipped to avoid needless work.
        }
    }
}
