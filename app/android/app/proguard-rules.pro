# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# OkHttp (used by Dio/Supabase)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Gson (JSON serialization)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Hive
-keep class ** extends com.google.protobuf.GeneratedMessageLite { *; }

# YouTube Player (WebView bridge)
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }

# Biometric / local_auth
-keep class androidx.biometric.** { *; }

# Google Play Core (referenced by Flutter deferred components)
-dontwarn com.google.android.play.core.**

# Keep R8 from stripping annotations
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
