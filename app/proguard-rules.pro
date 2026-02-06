# Add any ProGuard rules here
-keep class com.amaruwear.AmaruBridge { *; }
-keepclassmembers class com.amaruwear.AmaruBridge {
    native <methods>;
}
