package ru.ncti.schedule.client.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import ru.ncti.schedule.client.MainActivity
import ru.ncti.schedule.client.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class WeekSummaryWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        WidgetDiagnostic.log(context, "WeekSummaryWidget", "onReceive action=${intent.action}")
        try {
            super.onReceive(context, intent)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "WeekSummaryWidget", "onReceive FAILED", t)
            throw t
        }
    }

    override fun onEnabled(context: Context) {
        WidgetDiagnostic.log(context, "WeekSummaryWidget", "onEnabled")
        try {
            super.onEnabled(context)
            WidgetTickReceiver.ensureScheduled(context)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "WeekSummaryWidget", "onEnabled FAILED", t)
            throw t
        }
    }

    override fun onDisabled(context: Context) {
        WidgetDiagnostic.log(context, "WeekSummaryWidget", "onDisabled")
        try {
            super.onDisabled(context)
            WidgetTickReceiver.cancelIfIdle(context)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "WeekSummaryWidget", "onDisabled FAILED", t)
            throw t
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        WidgetDiagnostic.log(context, "WeekSummaryWidget", "onAppWidgetOptionsChanged id=$appWidgetId")
        try {
            super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
            // Resize-driven subject-row scaling: rebuild so taller heights
            // get more lines per day without waiting for the 15-min tick.
            onUpdate(
                context,
                appWidgetManager,
                intArrayOf(appWidgetId),
                es.antonborri.home_widget.HomeWidgetPlugin.getData(context),
            )
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "WeekSummaryWidget", "onAppWidgetOptionsChanged FAILED", t)
            throw t
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        WidgetDiagnostic.log(context, "WeekSummaryWidget", "onDeleted ids=${appWidgetIds.joinToString(",")}")
        try {
            super.onDeleted(context, appWidgetIds)
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "WeekSummaryWidget", "onDeleted FAILED", t)
            throw t
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        WidgetDiagnostic.log(context, "WeekSummaryWidget", "onUpdate ids=${appWidgetIds.joinToString(",")}")
        try {
            val theme = WidgetTheme.read(widgetData)
            val isCta = widgetData.getBoolean("widget_cta_mode", false)
            val json = widgetData.getString("widget_week_summary", "[]") ?: "[]"
            val arr = try { JSONArray(json) } catch (_: Exception) { JSONArray() }

            for (id in appWidgetIds) {
                val opts = appWidgetManager.getAppWidgetOptions(id)
                val minHeightDp = opts
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
                val minWidthDp = opts
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                // Launcher cell math varies a lot. Some launchers report the
                // widget's minimum 4x3 size as tall enough to trip the old
                // height-only split, even though the usable width is still
                // compact. Keep the whole week in one line until the widget
                // is both tall and wide enough for the two-row variant.
                val isTall = minHeightDp >= 280 && minWidthDp >= 380
                // The inline status dot now shares the header row with the
                // weekday label, so day-of-month needs a little more width
                // than before to avoid cramped ellipsizing.
                val showDom = isTall || minWidthDp >= 400
                val layoutRes = if (isTall)
                    R.layout.widget_week_summary_tall
                else
                    R.layout.widget_week_summary
                val views = RemoteViews(context.packageName, layoutRes)
                views.setInt(R.id.widget_week_root, "setBackgroundResource",
                    theme.backgroundRes)
                views.setInt(R.id.widget_week_accent, "setBackgroundColor", theme.accent)
                views.setTextColor(R.id.widget_week_title, theme.titleColor)

                if (isCta) {
                    views.setViewVisibility(R.id.widget_week_cta, View.VISIBLE)
                    views.setTextColor(R.id.widget_week_cta, theme.subtleColor)
                    views.setViewVisibility(R.id.widget_week_row, View.GONE)
                    if (isTall) {
                        views.setViewVisibility(R.id.widget_week_row_bot, View.GONE)
                    }
                    views.setOnClickPendingIntent(R.id.widget_week_root, openApp(context))
                    appWidgetManager.updateAppWidget(id, views)
                    continue
                }

                views.setViewVisibility(R.id.widget_week_cta, View.GONE)
                views.setViewVisibility(R.id.widget_week_row, View.VISIBLE)
                if (isTall) {
                    views.setViewVisibility(R.id.widget_week_row_bot, View.VISIBLE)
                }

                // Subject capacity is measured in fixed two-line lesson
                // boxes. The compact single-row layout can use almost the
                // whole widget height, so a 4x3-style resize should show
                // five real lessons before the overflow footer appears.
                val lessonsPerDay = if (isTall) {
                    when {
                        minHeightDp >= 300 -> 4
                        minHeightDp >= 260 -> 3
                        else -> 2
                    }
                } else {
                    when {
                        minHeightDp >= 300 -> 7
                        minHeightDp >= 240 -> 6
                        minHeightDp >= 170 -> 5
                        minHeightDp >= 130 -> 4
                        minHeightDp >= 110 -> 3
                        else -> 1
                    }
                }
                val visibleCubeCount = visibleWeekCubeCount(arr)
                val subjectLineChars = subjectLineCharBudget(
                    minWidthDp,
                    visibleCubeCount,
                    isTall,
                )
                val todayIso = currentDateIso()

                for (i in 0 until 7) {
                    val cubeId = cubeIds[i]
                    val labelId = labelIds[i]
                    val countId = countIds[i]
                    val dotId = dotIds[i]
                    val subjectsId = subjectsIds[i]
                    val obj: JSONObject? = if (i < arr.length()) arr.optJSONObject(i) else null
                    val label = obj?.optString("label", "—") ?: "—"
                    val bucket = obj?.optString("bucket", "empty") ?: "empty"
                    val dateIso = obj?.optString("date", "") ?: ""
                    val subjects = extractSubjects(obj)
                    val hasOverrides = obj?.optBoolean("hasOverrides", false) ?: false
                    val isToday = dateIso.isNotEmpty() && dateIso == todayIso
                    val isEmpty = bucket == "empty"

                    // Empty-weekend rule: hide Сб/Вс cubes (indices 5, 6) when
                    // they carry no lessons. LinearLayout redistributes the
                    // freed width among remaining visible cubes because the
                    // row's weightSum is deliberately unset.
                    if (isEmpty && (i == 5 || i == 6)) {
                        views.setViewVisibility(cubeId, View.GONE)
                        continue
                    } else {
                        views.setViewVisibility(cubeId, View.VISIBLE)
                    }

                    // Inline "Пн 20" — weekday and day-of-month in one line so
                    // the cube header doesn't eat a second vertical row. The
                    // separate count TextView is hidden; kept in XML so
                    // pre-1.1.1 layouts still inflate but out of the way.
                    // Narrow widget widths fall back to just the weekday
                    // letters so the header stays on a single line.
                    val dom = dayOfMonth(dateIso)
                    val inlineLabel = if (showDom && dom != "—") "$label $dom" else label
                    views.setTextViewText(
                        labelId,
                        formatLabel(inlineLabel, isEmpty, isToday, hasOverrides, theme),
                    )
                    views.setTextColor(
                        labelId,
                        if (isToday) Color.WHITE else theme.titleColor,
                    )
                    views.setViewVisibility(countId, View.GONE)

                    // The status marker is rendered inline with the weekday
                    // label. The legacy ImageView stays hidden so older XML
                    // IDs remain valid without spending a separate row.
                    views.setViewVisibility(dotId, View.GONE)

                    val formattedSubjects = formatSubjects(
                        subjects,
                        lessonsPerDay,
                        subjectLineChars,
                        separatorColor(if (isToday) Color.WHITE else theme.subtleColor),
                    )
                    views.setTextViewText(subjectsId, formattedSubjects.text)
                    views.setInt(
                        subjectsId,
                        "setMaxLines",
                        formattedSubjects.lineCount.coerceAtLeast(1),
                    )
                    views.setTextColor(
                        subjectsId,
                        if (isToday) Color.WHITE else theme.bodyColor,
                    )

                    // Rounded-rect per-cube bg: gives each day a visible
                    // edge so the row reads as 5-7 distinct cards instead
                    // of a continuous band. Today gets an accent-tinted
                    // variant; all others get a subtle surface tint. The
                    // drawables are themed (light/dark) — picked here
                    // because RemoteViews can't resolve ?attr/ references
                    // reliably at inflate time.
                    val cubeBgRes = when {
                        isToday && theme.isDark -> R.drawable.widget_week_cube_today_dark
                        isToday -> R.drawable.widget_week_cube_today_light
                        theme.isDark -> R.drawable.widget_week_cube_dark
                        else -> R.drawable.widget_week_cube_light
                    }
                    views.setInt(cubeId, "setBackgroundResource", cubeBgRes)

                    views.setOnClickPendingIntent(
                        cubeId,
                        openAppAtDate(context, dateIso),
                    )
                }

                views.setOnClickPendingIntent(
                    R.id.widget_week_root,
                    openAppAtDate(context, ""),
                )
                appWidgetManager.updateAppWidget(id, views)
            }
        } catch (t: Throwable) {
            WidgetDiagnostic.log(context, "WeekSummaryWidget", "onUpdate FAILED", t)
            throw t
        }
    }

    private data class WeekSubject(val ord: Int, val name: String)

    private fun extractSubjects(obj: JSONObject?): List<WeekSubject> {
        val arr = obj?.optJSONArray("subjects") ?: return emptyList()
        val out = ArrayList<WeekSubject>(arr.length())
        for (i in 0 until arr.length()) {
            val item = arr.opt(i) ?: continue
            when (item) {
                is JSONObject -> {
                    val name = item.optString("name", "").trim()
                    if (name.isEmpty()) continue
                    out.add(WeekSubject(item.optInt("ord", 0), name))
                }
                is String -> {
                    // Tolerate the pre-1.2.6 plain-string shape so a stale
                    // payload from before the upgrade still renders.
                    if (item.isNotEmpty()) out.add(WeekSubject(0, item))
                }
            }
        }
        return out
    }

    /// Weekday label plus a same-line status marker. Today keeps the old
    /// "ring" language with an outlined glyph, override days get amber, and
    /// regular non-empty days get the theme's subtle grey.
    private fun formatLabel(
        label: String,
        isEmpty: Boolean,
        isToday: Boolean,
        hasOverrides: Boolean,
        theme: WidgetTheme,
    ): CharSequence {
        if (isEmpty) return label
        val dot = if (isToday) " ○" else " ●"
        val sb = SpannableStringBuilder(label)
        val start = sb.length
        sb.append(dot)
        sb.setSpan(
            ForegroundColorSpan(dotTextColor(isToday, hasOverrides, theme)),
            start,
            sb.length,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
        sb.setSpan(
            RelativeSizeSpan(0.82f),
            start,
            sb.length,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
        return sb
    }

    private fun dotTextColor(
        isToday: Boolean,
        hasOverrides: Boolean,
        theme: WidgetTheme,
    ): Int = when {
        isToday -> Color.WHITE
        hasOverrides -> Color.parseColor("#EAB308")
        else -> theme.subtleColor
    }

    private data class FormattedSubjects(
        val text: CharSequence,
        val lineCount: Int,
    )

    /// Stacks subject names as fixed two-line lesson boxes with a bold "N."
    /// lesson-number prefix. The native TextView cannot enforce maxLines per
    /// lesson inside one RemoteViews field, so the text is pre-wrapped before
    /// it reaches Android layout. Overflow beyond [maxLessons] gets a compact
    /// "+N пар" footer after the visible lesson boxes.
    private fun formatSubjects(
        subjects: List<WeekSubject>,
        maxLessons: Int,
        lineChars: Int,
        dividerColor: Int,
    ): FormattedSubjects {
        if (subjects.isEmpty()) return FormattedSubjects("", 1)
        val visibleCount = maxLessons.coerceAtLeast(1).coerceAtMost(subjects.size)
        val visible = subjects.take(visibleCount)
        val rest = subjects.size - visibleCount
        val sb = SpannableStringBuilder()
        var lineCount = 0
        for ((idx, s) in visible.withIndex()) {
            if (idx > 0) sb.append('\n')
            val prefix = if (s.ord > 0) "${s.ord}. " else ""
            val lines = twoLineSubject(s.name.trim(), lineChars, prefix.length)
            if (prefix.isNotEmpty()) {
                val start = sb.length
                sb.append(prefix)
                sb.setSpan(
                    StyleSpan(Typeface.BOLD),
                    start,
                    sb.length,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
            sb.append(lines.first)
            sb.append('\n')
            appendSecondSubjectLine(
                sb,
                lines.second,
                lineChars,
                dividerColor,
                showRule = idx < visible.lastIndex || rest > 0,
            )
            lineCount += 2
        }
        if (rest > 0) {
            if (sb.isNotEmpty()) sb.append('\n')
            sb.append("+$rest ${pluralPairs(rest)}")
            lineCount += 1
        }
        return FormattedSubjects(sb, lineCount)
    }

    private data class SubjectLines(val first: String, val second: String)

    private fun appendSecondSubjectLine(
        sb: SpannableStringBuilder,
        line: String,
        lineChars: Int,
        dividerColor: Int,
        showRule: Boolean,
    ) {
        sb.append(line)
        if (!showRule) return

        val visibleChars = if (line == "\u00A0") 0 else line.length
        if (visibleChars > lineChars - 4) return

        val rule = if (visibleChars == 0) "────" else " ──"
        val start = sb.length
        sb.append(rule)
        sb.setSpan(
            ForegroundColorSpan(dividerColor),
            start,
            sb.length,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
        sb.setSpan(
            RelativeSizeSpan(0.72f),
            start,
            sb.length,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
    }

    private fun twoLineSubject(
        raw: String,
        lineChars: Int,
        prefixChars: Int,
    ): SubjectLines {
        val normalized = raw.replace(Regex("\\s+"), " ").trim()
        if (normalized.isEmpty()) return SubjectLines("\u00A0", "\u00A0")
        val firstLimit = (lineChars - prefixChars).coerceAtLeast(3)
        val first = takeLine(normalized, firstLimit)
        val second = ellipsizeLine(first.rest, lineChars).ifEmpty { "\u00A0" }
        return SubjectLines(first.line, second)
    }

    private data class LineTake(val line: String, val rest: String)

    private fun takeLine(raw: String, limit: Int): LineTake {
        val clean = raw.trim()
        if (clean.length <= limit) return LineTake(clean, "")
        val breakAt = clean.lastIndexOf(' ', startIndex = limit)
        if (breakAt >= 2) {
            return LineTake(
                clean.substring(0, breakAt).trimEnd(),
                clean.substring(breakAt + 1).trimStart(),
            )
        }
        return LineTake(
            clean.substring(0, limit).trimEnd(),
            clean.substring(limit).trimStart(),
        )
    }

    private fun ellipsizeLine(raw: String, limit: Int): String {
        val clean = raw.trim()
        if (clean.length <= limit) return clean
        val contentLimit = (limit - 1).coerceAtLeast(1)
        val breakAt = clean.lastIndexOf(' ', startIndex = contentLimit)
        val head = if (breakAt >= 2) {
            clean.substring(0, breakAt)
        } else {
            clean.substring(0, contentLimit)
        }
        return head.trimEnd() + "…"
    }

    private fun visibleWeekCubeCount(arr: JSONArray): Int {
        var count = 0
        for (i in 0 until 7) {
            val obj: JSONObject? = if (i < arr.length()) arr.optJSONObject(i) else null
            val bucket = obj?.optString("bucket", "empty") ?: "empty"
            if (bucket == "empty" && (i == 5 || i == 6)) continue
            count++
        }
        return count.coerceIn(1, 7)
    }

    private fun separatorColor(base: Int): Int {
        return Color.argb(
            72,
            Color.red(base),
            Color.green(base),
            Color.blue(base),
        )
    }

    private fun subjectLineCharBudget(
        minWidthDp: Int,
        visibleCubeCount: Int,
        isTall: Boolean,
    ): Int {
        val safeWidth = if (minWidthDp > 0) minWidthDp else 320
        val outerPadding = 24
        val cubeHorizontalMargins = visibleCubeCount * 4
        val cubeHorizontalPadding = 12
        val availableWidthDp = safeWidth - outerPadding - cubeHorizontalMargins
        val textWidthDp = availableWidthDp / visibleCubeCount - cubeHorizontalPadding
        val avgCharDp = if (isTall) 5.4f else 5.0f
        val rawBudget = (textWidthDp / avgCharDp).toInt()
        return rawBudget.coerceIn(if (isTall) 8 else 6, if (isTall) 18 else 15)
    }

    /// Russian plural rules for "пара" (lesson pair). Matches the helper
    /// in TodayScheduleWidgetProvider so "ещё N …" reads identically
    /// across widgets.
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

    private fun dayOfMonth(dateIso: String): String {
        // date is "yyyy-MM-dd" — safe to slice, but fall back to "—" for
        // empty/malformed values so the cube still shows something.
        if (dateIso.length < 10) return "—"
        val dd = dateIso.substring(8, 10)
        return dd.trimStart('0').ifEmpty { "0" }
    }

    private fun currentDateIso(): String {
        val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        fmt.timeZone = TimeZone.getDefault()
        return fmt.format(Date())
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

    companion object {
        private val cubeIds = intArrayOf(
            R.id.widget_week_cube0, R.id.widget_week_cube1,
            R.id.widget_week_cube2, R.id.widget_week_cube3,
            R.id.widget_week_cube4, R.id.widget_week_cube5,
            R.id.widget_week_cube6,
        )
        private val labelIds = intArrayOf(
            R.id.widget_week_label0, R.id.widget_week_label1,
            R.id.widget_week_label2, R.id.widget_week_label3,
            R.id.widget_week_label4, R.id.widget_week_label5,
            R.id.widget_week_label6,
        )
        private val countIds = intArrayOf(
            R.id.widget_week_count0, R.id.widget_week_count1,
            R.id.widget_week_count2, R.id.widget_week_count3,
            R.id.widget_week_count4, R.id.widget_week_count5,
            R.id.widget_week_count6,
        )
        private val dotIds = intArrayOf(
            R.id.widget_week_dot0, R.id.widget_week_dot1,
            R.id.widget_week_dot2, R.id.widget_week_dot3,
            R.id.widget_week_dot4, R.id.widget_week_dot5,
            R.id.widget_week_dot6,
        )
        private val subjectsIds = intArrayOf(
            R.id.widget_week_subjects0, R.id.widget_week_subjects1,
            R.id.widget_week_subjects2, R.id.widget_week_subjects3,
            R.id.widget_week_subjects4, R.id.widget_week_subjects5,
            R.id.widget_week_subjects6,
        )
    }
}
