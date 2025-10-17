# Flutter 包裝器
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Dart VM
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }

# Google Play Core (動態模塊)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp & Okio
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# Dio & Cookie
-keep class io.flutter.plugins.** { *; }
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }

# Retrofit (如果使用)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

# HTTP 相關
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**
-keep class android.net.http.** { *; }

# 保留所有 native 方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留序列化相關
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Cookie 相關
-keep class * implements java.net.CookieStore { *; }
-keep class java.net.CookieManager { *; }
-keep class java.net.HttpCookie { *; }
-keep class android.webkit.CookieManager { *; }

# SSL/TLS
-keep class javax.net.ssl.** { *; }
-keep class javax.security.** { *; }
-dontwarn javax.net.ssl.**
-keepclassmembers class * implements javax.net.ssl.SSLSocketFactory {
    *;
}

# SharedPreferences
-keep class androidx.preference.** { *; }

# 保留 WebView
-keep class android.webkit.** { *; }

# 保留自定義 View
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}

# 忽略警告
-dontwarn java.lang.invoke.**
-dontwarn **$$Lambda$*
-dontwarn java.lang.management.**
-dontwarn java.beans.**

# 保留泛型簽名
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# 保留行號信息（方便調試）
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# 保留註解
-keepattributes *Annotation*

# R8 完整模式
-allowaccessmodification
-repackageclasses
