package com.wabees.wabees_android

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.app.PendingIntent
import android.view.View
import org.json.JSONArray

class ConversationsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.wabees.OPEN_CHAT") {
            val phone = intent.getStringExtra("phone") ?: ""
            
            // Save target phone to SharedPreferences for app to read on launch
            if (phone.isNotEmpty()) {
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                prefs.edit().putString("widget_navigate_phone", phone).apply()
            }
            
            // Launch app normally (no deep link URI)
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            if (launchIntent != null) context.startActivity(launchIntent)
        }
    }

    companion object {
        fun updateWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
            val v = RemoteViews(context.packageName, R.layout.conversations_widget)
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val json = prefs.getString("widget_conversations", "[]") ?: "[]"
            val time = prefs.getString("widget_update_time", "") ?: ""
            val arr = try { JSONArray(json) } catch (_: Exception) { JSONArray() }

            v.setTextViewText(R.id.widget_time, time)

            // Whole widget click opens app
            val appIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (appIntent != null) {
                v.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(
                    context, 1, appIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }

            val rows    = intArrayOf(R.id.r0, R.id.r1, R.id.r2, R.id.r3, R.id.r4)
            val avatars = intArrayOf(R.id.a0, R.id.a1, R.id.a2, R.id.a3, R.id.a4)
            val names   = intArrayOf(R.id.n0, R.id.n1, R.id.n2, R.id.n3, R.id.n4)
            val msgs    = intArrayOf(R.id.m0, R.id.m1, R.id.m2, R.id.m3, R.id.m4)
            val times   = intArrayOf(R.id.t0, R.id.t1, R.id.t2, R.id.t3, R.id.t4)
            val unreads = intArrayOf(R.id.u0, R.id.u1, R.id.u2, R.id.u3, R.id.u4)

            for (i in rows.indices) {
                if (i < arr.length()) {
                    val o = arr.optJSONObject(i) ?: continue
                    val name = o.optString("name", "")
                    val msg = o.optString("message", "")
                    val tm = o.optString("time", "")
                    val phone = o.optString("phone", "")
                    val unread = o.optInt("unread", 0)

                    v.setViewVisibility(rows[i], View.VISIBLE)
                    v.setTextViewText(avatars[i], if (name.isNotEmpty()) name[0].uppercase() else "?")
                    v.setTextViewText(names[i], name)
                    v.setTextViewText(msgs[i], msg)
                    v.setTextViewText(times[i], tm)

                    // Unread badge
                    if (unread > 0) {
                        v.setViewVisibility(unreads[i], View.VISIBLE)
                        v.setTextViewText(unreads[i], if (unread > 9) "9+" else unread.toString())
                    } else {
                        v.setViewVisibility(unreads[i], View.GONE)
                    }

                    // Per-row click → save phone to prefs + launch app
                    val ci = Intent(context, ConversationsWidgetProvider::class.java).apply {
                        action = "com.wabees.OPEN_CHAT"
                        putExtra("phone", phone)
                        // Unique data URI so Android doesn't collapse intents
                        data = Uri.parse("wabees://w/$i")
                    }
                    v.setOnClickPendingIntent(rows[i], PendingIntent.getBroadcast(
                        context, 100 + i, ci, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE))
                } else {
                    v.setViewVisibility(rows[i], View.GONE)
                }
            }

            v.setViewVisibility(R.id.widget_empty, if (arr.length() == 0) View.VISIBLE else View.GONE)
            mgr.updateAppWidget(widgetId, v)
        }
    }
}
