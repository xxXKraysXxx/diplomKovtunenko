package ru.ncti.schedule.client.widgets

import android.content.Context
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object WidgetDiagnostic {
    private const val LOG_FILE = "widget-errors.log"
    private const val MAX_LINES = 500

    fun log(context: Context, tag: String, message: String, error: Throwable? = null) {
        try {
            val dir = context.getExternalFilesDir(null) ?: return
            val file = File(dir, LOG_FILE)
            val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
            val line = StringBuilder()
            line.append('[').append(ts).append("] ").append(tag).append(' ').append(message)
            if (error != null) {
                line.append('\n').append(error.javaClass.name).append(": ").append(error.message).append('\n')
                error.stackTrace.take(20).forEach { line.append("    at ").append(it).append('\n') }
                var cause = error.cause
                while (cause != null) {
                    line.append("Caused by: ").append(cause.javaClass.name).append(": ").append(cause.message).append('\n')
                    cause.stackTrace.take(10).forEach { line.append("    at ").append(it).append('\n') }
                    cause = cause.cause
                }
            }
            line.append('\n')
            FileWriter(file, true).use { it.write(line.toString()) }
            rotate(file)
        } catch (_: Throwable) {
            // Silently ignore logger failures — don't cascade into widget crash
        }
    }

    private fun rotate(file: File) {
        try {
            val lines = file.readLines()
            if (lines.size > MAX_LINES) {
                file.writeText(lines.takeLast(MAX_LINES).joinToString("\n") + "\n")
            }
        } catch (_: Throwable) {}
    }
}
