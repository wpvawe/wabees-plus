package com.wabees.wabees_android

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.view.View
import org.json.JSONArray

class ConversationsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ConversationsRemoteViewsFactory(applicationContext)
    }
}

class ConversationsRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private var conversations: List<ConversationItem> = emptyList()

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val json = prefs.getString("widget_conversations", "[]") ?: "[]"
            val arr = JSONArray(json)

            val items = mutableListOf<ConversationItem>()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                items.add(ConversationItem(
                    name = obj.optString("name", "Unknown"),
                    message = obj.optString("message", ""),
                    time = obj.optString("time", ""),
                    phone = obj.optString("phone", ""),
                    unread = obj.optInt("unread", 0)
                ))
            }
            conversations = items
        } catch (e: Exception) {
            conversations = emptyList()
        }
    }

    override fun getCount(): Int = conversations.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.conversations_widget_item)
        if (position >= conversations.size) return views

        val item = conversations[position]

        // Avatar — first letter
        val initial = if (item.name.isNotEmpty()) item.name[0].uppercase() else "?"
        views.setTextViewText(R.id.item_avatar, initial)

        // Name + message
        views.setTextViewText(R.id.item_name, item.name)
        views.setTextViewText(R.id.item_message, item.message)
        views.setTextViewText(R.id.item_time, item.time)

        // Unread badge
        if (item.unread > 0) {
            views.setViewVisibility(R.id.item_unread, View.VISIBLE)
            views.setTextViewText(R.id.item_unread, if (item.unread > 9) "9+" else item.unread.toString())
        } else {
            views.setViewVisibility(R.id.item_unread, View.GONE)
        }

        // Fill-in intent for click
        val fillInIntent = Intent().apply {
            putExtra("phone", item.phone)
        }
        views.setOnClickFillInIntent(R.id.widget_item_root, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
    override fun onDestroy() {}
}

data class ConversationItem(
    val name: String,
    val message: String,
    val time: String,
    val phone: String,
    val unread: Int
)
