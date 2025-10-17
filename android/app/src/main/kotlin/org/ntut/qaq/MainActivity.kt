package org.ntut.qaq

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.ntut.qaq.widget.CourseWidgetProvider

class MainActivity: FlutterActivity() {
    private val WIDGET_CHANNEL = "org.ntut.qaq/widget"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val coursesJson = call.argument<String>("courses")
                    if (coursesJson != null) {
                        updateWidget(coursesJson)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "courses is null", null)
                    }
                }
                "updateWidgetImage" -> {
                    val imagePath = call.argument<String>("imagePath")
                    if (imagePath != null) {
                        updateWidgetImage(imagePath)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "imagePath is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun updateWidget(coursesJson: String) {
        // 保存課程數據到 SharedPreferences
        val prefs = getSharedPreferences(CourseWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(CourseWidgetProvider.PREF_TODAY_COURSES, coursesJson)
            .apply()
        
        // 通知所有 Widget 更新
        notifyWidgetUpdate()
    }
    
    private fun updateWidgetImage(imagePath: String) {
        // 保存圖片路徑到 SharedPreferences
        val prefs = getSharedPreferences(CourseWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString("course_table_image_path", imagePath)
            .apply()
        
        // 通知 Widget 更新
        notifyWidgetUpdate()
    }
    
    private fun notifyWidgetUpdate() {
        val intent = Intent(this, CourseWidgetProvider::class.java)
        intent.action = CourseWidgetProvider.ACTION_UPDATE_WIDGET
        
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(this, CourseWidgetProvider::class.java)
        )
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        
        sendBroadcast(intent)
    }
}
