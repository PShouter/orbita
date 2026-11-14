# Flutter / Dart
-keepattributes *Annotation*
-keepattributes Signature
-keep class io.flutter.** { *; }

# Gson используется плагинами для сериализации уведомлений
-keep class com.google.gson.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Не предупреждать о необязательных зависимостях плагинов
-dontwarn com.google.gson.**

# Play Core нужен только для deferred components, приложение его не использует
-dontwarn com.google.android.play.core.**
