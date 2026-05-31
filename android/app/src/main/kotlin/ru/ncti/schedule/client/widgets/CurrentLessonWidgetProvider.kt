package ru.ncti.schedule.client.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import ru.ncti.schedule.client.MainActivity
import ru.ncti.schedule.client.R

class CurrentLessonWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        WidgetDiagnostic.log(context, "CurrentLessonWidget", "onReceive action=${intent.action}")
        try {
            super.onReceive(context, intent)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "CurrentLessonWidget", "onReceive FAILED", t)
            throw t
        }
    }

    override fun onEnabled(context: Context) {
        WidgetDiagnostic.log(context, "CurrentLessonWidget", "onEnabled")
        try {
            super.onEnabled(context)
            WidgetTickReceiver.ensureScheduled(context)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "CurrentLessonWidget", "onEnabled FAILED", t)
            throw t
        }
    }

    override fun onDisabled(context: Context) {
        WidgetDiagnostic.log(context, "CurrentLessonWidget", "onDisabled")
        try {
            super.onDisabled(context)
            WidgetTickReceiver.cancelIfIdle(context)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "CurrentLessonWidget", "onDisabled FAILED", t)
            throw t
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        WidgetDiagnostic.log(context, "CurrentLessonWidget", "onAppWidgetOptionsChanged id=$appWidgetId")
        try {
            super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
            // AppWidgetProvider does NOT auto-trigger onUpdate on resize, so
            // we explicitly rebuild this instance so the tall-mode threshold
            // (≥ ~110dp) picks up immediately.
            onUpdate(
                context,
                appWidgetManager,
                intArrayOf(appWidgetId),
                HomeWidgetPlugin.getData(context),
            )
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "CurrentLessonWidget", "onAppWidgetOptionsChanged FAILED", t)
            throw t
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        WidgetDiagnostic.log(context, "CurrentLessonWidget", "onDeleted ids=${appWidgetIds.joinToString(",")}")
        try {
            super.onDeleted(context, appWidgetIds)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "CurrentLessonWidget", "onDeleted FAILED", t)
            throw t
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        WidgetDiagnostic.log(context, "CurrentLessonWidget", "onUpdate ids=${appWidgetIds.joinToString(",")}")
        try {
            // Re-seed the minute ticker on every framework-driven update. The
            // AppWidget 30-min pulse and any explicit poke both land here, so
            // a lost alarm (post-reboot, post-app-update, etc.) self-heals
            // without needing RECEIVE_BOOT_COMPLETED.
            WidgetTickReceiver.ensureScheduled(context)
            val theme = WidgetTheme.read(widgetData)
            val isCta = widgetData.getBoolean("widget_cta_mode", false)
            val state = widgetData.getString("widget_current_lesson_state", "idle") ?: "idle"
            val subject = widgetData.getString("widget_current_lesson_subject", "") ?: ""
            val room = widgetData.getString("widget_current_lesson_room", "") ?: ""
            // Live countdown: we prefer the absolute epoch the Dart side writes
            // (seconds since unix epoch) so the minute-tick receiver can
            // re-render a fresh "осталось X мин" without waking Dart. The legacy
            // int field stays as a fallback for upgrade continuity.
            val nowSec = System.currentTimeMillis() / 1000L
            val endEpoch = widgetData.getString(
                "widget_current_lesson_end_epoch_s", "0"
            )?.toLongOrNull() ?: 0L
            val startEpoch = widgetData.getString(
                "widget_current_lesson_start_epoch_s", "0"
            )?.toLongOrNull() ?: 0L
            val storedMins = widgetData.getInt("widget_current_lesson_starts_in_min", 0)
            val mins = when (state) {
                "current" -> if (endEpoch > 0) {
                    ((endEpoch - nowSec) / 60L).toInt().coerceAtLeast(0)
                } else storedMins
                "next" -> if (startEpoch > 0) {
                    ((startEpoch - nowSec) / 60L).toInt().coerceAtLeast(0)
                } else storedMins
                else -> 0
            }
            val nextSubject = widgetData.getString("widget_next_lesson_subject", "") ?: ""
            val nextRoom = widgetData.getString("widget_next_lesson_room", "") ?: ""
            val nextLabel = widgetData.getString("widget_next_lesson_label", "") ?: ""
            val prevSubject = widgetData.getString("widget_prev_lesson_subject", "") ?: ""
            val prevRoom = widgetData.getString("widget_prev_lesson_room", "") ?: ""
            val prevLabel = widgetData.getString("widget_prev_lesson_label", "") ?: ""
            val afterNextSubject = widgetData.getString("widget_after_next_subject", "") ?: ""
            val afterNextRoom = widgetData.getString("widget_after_next_room", "") ?: ""
            val afterNextLabel = widgetData.getString("widget_after_next_label", "") ?: ""

            for (id in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_current_lesson)
                views.setInt(R.id.widget_current_root, "setBackgroundResource",
                    theme.backgroundRes)
                views.setInt(R.id.widget_current_accent, "setBackgroundColor", theme.accent)
                views.setInt(R.id.widget_current_prev_accent, "setBackgroundColor", theme.accent)

                if (isCta) {
                    renderCta(views, theme)
                    views.setOnClickPendingIntent(R.id.widget_current_root, openApp(context))
                    appWidgetManager.updateAppWidget(id, views)
                    continue
                }

                val (headline, detail) = when (state) {
                    "current" -> {
                        val tail = if (mins > 0) " · осталось $mins мин" else ""
                        Pair("Идёт сейчас", "$subject · $room$tail")
                    }
                    "next" -> {
                        val tail = if (mins > 0) "через $mins мин" else "скоро"
                        Pair("Следующая $tail", "$subject · $room")
                    }
                    else -> Pair("Занятий больше нет", "")
                }
                views.setTextViewText(R.id.widget_current_headline, headline)
                views.setTextColor(R.id.widget_current_headline, theme.headlineColor)
                views.setTextViewText(R.id.widget_current_detail, detail)
                views.setTextColor(R.id.widget_current_detail, theme.bodyColor)

                // Size buckets: landscape min-height from
                // OPTION_APPWIDGET_MIN_HEIGHT is the shorter orientation,
                // which is what we want to pivot on.
                //   < 110dp      → small  (3x1): headline + next footer
                //   110–200dp    → medium (3x2): prev + headline + next footer
                //   ≥ 200dp      → large  (3x3): prev + headline + next + after-next
                val minHeightDp = appWidgetManager
                    .getAppWidgetOptions(id)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
                val mediumMode = minHeightDp >= 110
                val largeMode = minHeightDp >= 200

                // Prev row: only in medium/large AND when we actually have
                // something (first slot of the day has no "prev"; idle state
                // shouldn't show stale data either).
                val showPrev = mediumMode && prevSubject.isNotEmpty() && state != "idle"
                if (showPrev) {
                    views.setViewVisibility(R.id.widget_current_prev_row, View.VISIBLE)
                    views.setTextViewText(R.id.widget_current_prev_label, prevLabel)
                    views.setTextColor(R.id.widget_current_prev_label, theme.subtleColor)
                    val prevDetail = if (prevRoom.isNotEmpty()) "$prevSubject · $prevRoom" else prevSubject
                    views.setTextViewText(R.id.widget_current_prev_detail, prevDetail)
                    views.setTextColor(R.id.widget_current_prev_detail, theme.subtleColor)
                } else {
                    views.setViewVisibility(R.id.widget_current_prev_row, View.GONE)
                }

                // Next row: shown whenever we have a distinct "next" slot. In
                // the "state=next" case the headline row already is that
                // slot, so we suppress the footer to avoid duplicating it.
                val showNext = nextSubject.isNotEmpty() && state != "next"
                if (showNext) {
                    views.setViewVisibility(R.id.widget_current_next_row, View.VISIBLE)
                    views.setTextViewText(R.id.widget_current_next_label,
                        if (nextLabel.isNotEmpty()) nextLabel else "Далее")
                    views.setTextColor(R.id.widget_current_next_label, theme.headlineColor)
                    val nextDetail = if (nextRoom.isNotEmpty()) "$nextSubject · $nextRoom" else nextSubject
                    views.setTextViewText(R.id.widget_current_next_detail, nextDetail)
                    views.setTextColor(R.id.widget_current_next_detail, theme.subtleColor)
                } else {
                    views.setViewVisibility(R.id.widget_current_next_row, View.GONE)
                }

                // After-next row: large mode only. If state=next then the
                // "next" slot is in the headline, so the runner-up shown here
                // is actually the first afterNext entry — which is still what
                // the Dart side wrote into `widget_after_next_*`, so no
                // remapping needed.
                val showAfterNext = largeMode && afterNextSubject.isNotEmpty() && state != "idle"
                if (showAfterNext) {
                    views.setViewVisibility(R.id.widget_current_after_next_row, View.VISIBLE)
                    views.setTextViewText(R.id.widget_current_after_next_label,
                        if (afterNextLabel.isNotEmpty()) afterNextLabel else "Затем")
                    views.setTextColor(R.id.widget_current_after_next_label, theme.subtleColor)
                    val detail = if (afterNextRoom.isNotEmpty())
                        "$afterNextSubject · $afterNextRoom" else afterNextSubject
                    views.setTextViewText(R.id.widget_current_after_next_detail, detail)
                    views.setTextColor(R.id.widget_current_after_next_detail, theme.subtleColor)
                } else {
                    views.setViewVisibility(R.id.widget_current_after_next_row, View.GONE)
                }

                views.setOnClickPendingIntent(R.id.widget_current_root, openApp(context))
                appWidgetManager.updateAppWidget(id, views)
            }
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "CurrentLessonWidget", "onUpdate FAILED", t)
            throw t
        }
    }

    private fun renderCta(views: RemoteViews, theme: WidgetTheme) {
        views.setTextViewText(R.id.widget_current_headline, "Настройте виджет")
        views.setTextColor(R.id.widget_current_headline, theme.headlineColor)
        views.setTextViewText(R.id.widget_current_detail,
            "Выберите группу или преподавателя")
        views.setTextColor(R.id.widget_current_detail, theme.bodyColor)
        views.setViewVisibility(R.id.widget_current_prev_row, View.GONE)
        views.setViewVisibility(R.id.widget_current_next_row, View.GONE)
        views.setViewVisibility(R.id.widget_current_after_next_row, View.GONE)
    }

    private fun openApp(context: Context): PendingIntent {
        return HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("ncti://widget/schedule"),
        )
    }
}
