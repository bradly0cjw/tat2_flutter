package org.ntut.qaq.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.util.Log
import android.widget.RemoteViews
import org.ntut.qaq.MainActivity
import org.ntut.qaq.R
import java.io.File

class CourseWidgetProvider : AppWidgetProvider() {
    
    companion object {
        private const val TAG = "CourseWidget"
        const val ACTION_UPDATE_WIDGET = "org.ntut.qaq.UPDATE_WIDGET"
        const val PREFS_NAME = "CourseWidgetPrefs"
        const val PREF_TODAY_COURSES = "today_courses"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called with ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        Log.d(TAG, "updateWidget: $appWidgetId")
        
        val views = RemoteViews(context.packageName, R.layout.course_widget)
        
        // 設置點擊事件（開啟應用）
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.course_widget_container, pendingIntent)
        
        // 從 SharedPreferences 讀取圖片路徑
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val imagePath = prefs.getString("course_table_image_path", null)
        
        if (imagePath != null) {
            val imageFile = File(imagePath)
            if (imageFile.exists()) {
                try {
                    val bitmap = BitmapFactory.decodeFile(imagePath)
                    if (bitmap != null) {
                        Log.d(TAG, "載入課表圖片成功: $imagePath, 尺寸: ${bitmap.width}x${bitmap.height}")
                        views.setImageViewBitmap(R.id.course_table_image, bitmap)
                        views.setViewVisibility(R.id.widget_title, android.view.View.GONE)
                    } else {
                        Log.e(TAG, "課表圖片解碼失敗: $imagePath")
                        showError(views, "載入失敗")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "載入課表圖片時發生錯誤: $imagePath", e)
                    showError(views, "載入錯誤")
                }
            } else {
                Log.w(TAG, "課表圖片不存在: $imagePath")
                showError(views, "圖片不存在")
            }
        } else {
            Log.w(TAG, "尚未設置課表圖片路徑")
            showError(views, "尚未載入課表")
        }
        
        Log.d(TAG, "更新小工具 $appWidgetId")
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    
    private fun showError(views: RemoteViews, message: String) {
        views.setViewVisibility(R.id.widget_title, android.view.View.VISIBLE)
        views.setTextViewText(R.id.widget_title, message)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d(TAG, "onReceive: ${intent.action}")
        
        if (intent.action == ACTION_UPDATE_WIDGET) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, CourseWidgetProvider::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        Log.d(TAG, "Widget disabled")
    }
}