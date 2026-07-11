# ML Kit Text Recognition Proguard rules to ignore missing optional language models
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Android Jetpack WorkManager and Room database keep rules (fixes release startup crash)
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**
-dontwarn androidx.work.**

