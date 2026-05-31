package ru.ncti.schedule.client.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import ru.ncti.schedule.client.MainActivity
import ru.ncti.schedule.client.R

class TodayScheduleWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        WidgetDiagnostic.log(context, "TodayScheduleWidget", "onReceive action=${intent.action}")
        try {
            super.onReceive(context, intent)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "TodayScheduleWidget", "onReceive FAILED", t)
            throw t
        }
    }

    override fun onEnabled(context: Context) {
        WidgetDiagnostic.log(context, "TodayScheduleWidget", "onEnabled")
        try {
            super.onEnabled(context)
            WidgetTickReceiver.ensureScheduled(context)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "TodayScheduleWidget", "onEnabled FAILED", t)
            throw t
        }
    }

    override fun onDisabled(context: Context) {
        WidgetDiagnostic.log(context, "TodayScheduleWidget", "onDisabled")
        try {
            super.onDisabled(context)
            WidgetTickReceiver.cancelIfIdle(context)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "TodayScheduleWidget", "onDisabled FAILED", t)
            throw t
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        WidgetDiagnostic.log(context, "TodayScheduleWidget", "onAppWidgetOptionsChanged id=$appWidgetId")
        try {
            super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
            // Refit the row count to the new available height.
            onUpdate(
                context,
                appWidgetManager,
                intArrayOf(appWidgetId),
                HomeWidgetPlugin.getData(context),
            )
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "TodayScheduleWidget", "onAppWidgetOptionsChanged FAILED", t)
            throw t
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        WidgetDiagnostic.log(context, "TodayScheduleWidget", "onDeleted ids=${appWidgetIds.joinToString(",")}")
        try {
            super.onDeleted(context, appWidgetIds)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "TodayScheduleWidget", "onDeleted FAILED", t)
            throw t
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        WidgetDiagnostic.log(context, "TodayScheduleWidget", "onUpdate ids=${appWidgetIds.joinToString(",")}")
        try {
            WidgetTickReceiver.ensureScheduled(context)
            val theme = WidgetTheme.read(widgetData)
            val isCta = widgetData.getBoolean("widget_cta_mode", false)
            val lessonsJson = widgetData.getString("widget_today_lessons", "[]") ?: "[]"
            val label = widgetData.getString("widget_today_label", "Сегодня") ?: "Сегодня"
            val dateIso = widgetData.getString("widget_today_date_iso", "") ?: ""
            val isFallback = widgetData.getBoolean("widget_today_is_fallback", false)
            // Current-lesson state feeds the row highlight and 4x3 hint block.
            val currentState = widgetData.getString("widget_current_lesson_state", "idle") ?: "idle"
            val currentSubject = widgetData.getString("widget_current_lesson_subject", "") ?: ""
            val currentRoom = widgetData.getString("widget_current_lesson_room", "") ?: ""
            // Live countdown: see CurrentLessonWidgetProvider for rationale. If
            // the epoch isn't available yet (older Dart payload), keep using the
            // stored int so the hint block still reads sensibly.
            val nowSec = System.currentTimeMillis() / 1000L
            val endEpoch = widgetData.getString(
                "widget_current_lesson_end_epoch_s", "0"
            )?.toLongOrNull() ?: 0L
            val startEpoch = widgetData.getString(
                "widget_current_lesson_start_epoch_s", "0"
            )?.toLongOrNull() ?: 0L
            val storedMins = widgetData.getInt("widget_current_lesson_starts_in_min", 0)
            val currentMins = when (currentState) {
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

            for (id in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_today_schedule)
                views.setInt(R.id.widget_today_root, "setBackgroundResource",
                    theme.backgroundRes)
                views.setInt(R.id.widget_today_accent, "setBackgroundColor", theme.accent)
                views.setTextColor(R.id.widget_today_title, theme.titleColor)

                if (isCta) {
                    views.setTextViewText(R.id.widget_today_title, "Расписание")
                    views.setViewVisibility(R.id.widget_today_header, View.VISIBLE)
                    views.removeAllViews(R.id.widget_today_list)
                    views.setViewVisibility(R.id.widget_today_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_today_empty,
                        "Выберите группу или преподавателя")
                    views.setTextColor(R.id.widget_today_empty, theme.subtleColor)
                    views.setViewVisibility(R.id.widget_today_more, View.GONE)
                    views.setViewVisibility(R.id.widget_today_hint, View.GONE)
                    views.setOnClickPendingIntent(R.id.widget_today_root, openApp(context))
                    appWidgetManager.updateAppWidget(id, views)
                    continue
                }

                views.setTextViewText(R.id.widget_today_title, label)
                views.removeAllViews(R.id.widget_today_list)
                val items = try { JSONArray(lessonsJson) } catch (_: Exception) { JSONArray() }

                val minHeightDp = appWidgetManager
                    .getAppWidgetOptions(id)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
                val minWidthDp = appWidgetManager
                    .getAppWidgetOptions(id)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)

                // Compact mode: at sub-80dp heights the 48dp title row eats
                // so much of the frame that the "ещё N" footer gets clipped.
                // Hide the title to buy back that budget.
                val compact = minHeightDp in 1..79
                views.setViewVisibility(
                    R.id.widget_today_header,
                    if (compact) View.GONE else View.VISIBLE,
                )

                // 4x3 triggers the hint block: a full-width detail panel for
                // the current-or-next lesson. Only shown when we actually have
                // surplus room below the rendered rows.
                val hintMode = minWidthDp >= 300 && minHeightDp >= 220

                if (items.length() == 0) {
                    views.setViewVisibility(R.id.widget_today_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_today_empty,
                        "Нет занятий — откройте приложение")
                    views.setTextColor(R.id.widget_today_empty, theme.subtleColor)
                    views.setViewVisibility(R.id.widget_today_more, View.GONE)
                    views.setViewVisibility(R.id.widget_today_hint, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_today_empty, View.GONE)

                    // Locate the "highlight" slot: prefer a currently-running
                    // lesson (state=current, match subject+room); otherwise
                    // the first upcoming lesson (state=next). The returned
                    // index is -1 when nothing matches (e.g. fallback day
                    // still loading, or gap between lessons without state).
                    val highlightIndex = locateHighlight(
                        items = items,
                        state = currentState,
                        currentSubject = currentSubject,
                        currentRoom = currentRoom,
                        nextSubject = nextSubject,
                        nextRoom = nextRoom,
                        isFallback = isFallback,
                    )

                    val fit = fittingRowCount(minHeightDp, compact, hintMode)
                    val overflow = items.length() - fit
                    val shown = if (overflow > 0) fit else items.length()
                    for (i in 0 until shown) {
                        val o = items.getJSONObject(i)
                        val row = RemoteViews(context.packageName, R.layout.widget_lesson_row)
                        val slot = o.optInt("ordinal", 0).toString()
                        val start = o.optString("start", "")
                        val end = o.optString("end", "")
                        val subject = o.optString("subject", "—")
                        val classroom = o.optString("classroom", "")
                        val teacher = o.optString("teacher", "")
                        val metaParts = mutableListOf<String>()
                        if (teacher.isNotEmpty()) metaParts.add(teacher)
                        if (classroom.isNotEmpty()) metaParts.add(classroom)
                        row.setTextViewText(R.id.widget_row_slot, slot)
                        row.setTextColor(R.id.widget_row_slot, theme.accent)
                        row.setTextViewText(R.id.widget_row_subject, subject)
                        row.setTextColor(R.id.widget_row_subject, theme.bodyColor)
                        row.setTextViewText(R.id.widget_row_meta, metaParts.joinToString(" · "))
                        row.setTextColor(R.id.widget_row_meta, theme.subtleColor)
                        // Time range: falls back to a +95min synthesized end
                        // when the slot table doesn't carry an end for the
                        // ordinal (slot 10 today; keep behaviour future-proof
                        // for any stray slots that lack a hard end).
                        val timeRange = formatTimeRange(start, end)
                        row.setTextViewText(R.id.widget_row_time, timeRange)
                        row.setTextColor(R.id.widget_row_time, theme.subtleColor)
                        if (i == highlightIndex) {
                            row.setViewVisibility(R.id.widget_row_accent, View.VISIBLE)
                            row.setInt(R.id.widget_row_accent, "setBackgroundColor", theme.accent)
                            row.setInt(R.id.widget_row_root, "setBackgroundColor",
                                withAlpha(theme.accent, if (theme.isDark) 48 else 28))
                        } else {
                            row.setViewVisibility(R.id.widget_row_accent, View.INVISIBLE)
                            row.setInt(R.id.widget_row_root, "setBackgroundColor",
                                Color.TRANSPARENT)
                        }
                        views.addView(R.id.widget_today_list, row)
                    }
                    if (overflow > 0) {
                        views.setViewVisibility(R.id.widget_today_more, View.VISIBLE)
                        views.setTextViewText(
                            R.id.widget_today_more,
                            "ещё $overflow " + pluralPairs(overflow),
                        )
                        views.setTextColor(R.id.widget_today_more, theme.subtleColor)
                    } else {
                        views.setViewVisibility(R.id.widget_today_more, View.GONE)
                    }

                    // Hint block: only when we have both the surplus real
                    // estate (4x3 bucket) and a meaningful highlight source.
                    if (hintMode && highlightIndex >= 0) {
                        val o = items.getJSONObject(highlightIndex)
                        val subject = o.optString("subject", "—")
                        val classroom = o.optString("classroom", "")
                        val teacher = o.optString("teacher", "")
                        val start = o.optString("start", "")
                        val end = o.optString("end", "")
                        val labelText = when {
                            currentState == "current" && !isFallback ->
                                if (currentMins > 0) "Сейчас · осталось $currentMins мин"
                                else "Сейчас"
                            nextLabel.isNotEmpty() -> nextLabel
                            else -> "Следующая"
                        }
                        val metaParts = mutableListOf<String>()
                        if (teacher.isNotEmpty()) metaParts.add(teacher)
                        if (classroom.isNotEmpty()) metaParts.add(classroom)
                        val timeRange = formatTimeRange(start, end)
                        if (timeRange.isNotEmpty()) metaParts.add(timeRange)
                        views.setViewVisibility(R.id.widget_today_hint, View.VISIBLE)
                        views.setInt(R.id.widget_today_hint_accent,
                            "setBackgroundColor", theme.accent)
                        views.setTextViewText(R.id.widget_today_hint_label, labelText)
                        views.setTextColor(R.id.widget_today_hint_label, theme.accent)
                        views.setTextViewText(R.id.widget_today_hint_subject, subject)
                        views.setTextColor(R.id.widget_today_hint_subject, theme.bodyColor)
                        views.setTextViewText(R.id.widget_today_hint_meta,
                            metaParts.joinToString(" · "))
                        views.setTextColor(R.id.widget_today_hint_meta, theme.subtleColor)
                    } else {
                        views.setViewVisibility(R.id.widget_today_hint, View.GONE)
                    }
                }

                views.setOnClickPendingIntent(
                    R.id.widget_today_root,
                    openAppAtDate(context, dateIso),
                )
                appWidgetManager.updateAppWidget(id, views)
            }
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "TodayScheduleWidget", "onUpdate FAILED", t)
            throw t
        }
    }

    /// Reserves room for the (optional) header, the "ещё N" footer and the
    /// 4x3 hint block, then divides the remainder by the ~34dp row height.
    /// Biased to show at least one row even when budgets run negative.
    private fun fittingRowCount(
        minHeightDp: Int,
        compact: Boolean,
        hintMode: Boolean,
    ): Int {
        if (minHeightDp <= 0) return 2
        val headerCost = if (compact) 0 else 34
        val hintCost = if (hintMode) 72 else 0
        // Padding: 10dp top + 10dp bottom on the root.
        val chrome = 20 + headerCost + hintCost
        val available = (minHeightDp - chrome).coerceAtLeast(0)
        return (available / 34).coerceIn(1, 8)
    }

    private fun formatTimeRange(start: String, end: String): String {
        if (start.isEmpty() && end.isEmpty()) return ""
        if (end.isEmpty()) {
            // Slot table didn't supply an end — synthesize +95min from the
            // start so the row still shows a range instead of a bare start
            // time. Keeps parity with the average pair length across slots
            // 1–8 (which span 90–95min with a mid-break).
            return synthesizeEnd(start)?.let { "$start–$it" } ?: start
        }
        if (start.isEmpty()) return end
        return "$start–$end"
    }

    private fun synthesizeEnd(start: String): String? {
        val parts = start.split(":")
        if (parts.size != 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        var total = h * 60 + m + 95
        total %= 24 * 60
        val hh = (total / 60).toString().padStart(2, '0')
        val mm = (total % 60).toString().padStart(2, '0')
        return "$hh:$mm"
    }

    /// Returns the index of the lesson that should carry the row accent +
    /// tint (the current one while running, otherwise the next upcoming).
    /// Matches on subject+classroom since the list doesn't carry a globally
    /// unique id; mismatches yield -1 so no row gets a stale highlight.
    private fun locateHighlight(
        items: JSONArray,
        state: String,
        currentSubject: String,
        currentRoom: String,
        nextSubject: String,
        nextRoom: String,
        isFallback: Boolean,
    ): Int {
        if (items.length() == 0) return -1
        if (isFallback) {
            // Display day is a future fallback; highlight the first slot as
            // the "next" lesson for visual continuity.
            return 0
        }
        val (targetSubject, targetRoom) = when (state) {
            "current" -> currentSubject to currentRoom
            "next" -> nextSubject to nextRoom
            else -> return -1
        }
        if (targetSubject.isEmpty()) return -1
        for (i in 0 until items.length()) {
            val o = items.optJSONObject(i) ?: continue
            if (o.optString("subject", "") == targetSubject &&
                o.optString("classroom", "") == targetRoom) {
                return i
            }
        }
        return -1
    }

    private fun withAlpha(color: Int, alpha: Int): Int {
        val a = alpha.coerceIn(0, 255)
        return (a shl 24) or (color and 0x00FFFFFF)
    }

    private fun openApp(context: Context): PendingIntent {
        return HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("ncti://widget/schedule"),
        )
    }

    private fun openAppAtDate(context: Context, dateIso: String): PendingIntent {
        val uri = if (dateIso.isNotEmpty()) {
            Uri.parse("ncti://widget/schedule?date=$dateIso")
        } else {
            Uri.parse("ncti://widget/schedule")
        }
        return HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, uri,
        )
    }

    private fun pluralPairs(n: Int): String {
        val mod100 = n % 100
        val mod10 = n % 10
        return when {
            mod100 in 11..14 -> "пар"
            mod10 == 1 -> "пара"
            mod10 in 2..4 -> "пары"
            else -> "пар"
        }
    }

    companion object {
        fun pokeAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, TodayScheduleWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(context, TodayScheduleWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        }
    }
}
