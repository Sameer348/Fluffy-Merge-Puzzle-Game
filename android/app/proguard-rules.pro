# R8 rules for release builds. Plugins (audioplayers, in_app_purchase /
# Play Billing, shared_preferences) ship their own consumer rules; these
# cover what Flutter itself references but doesn't bundle.

# Flutter's deferred-components support references Play Core, which this
# app doesn't use or include.
-dontwarn com.google.android.play.core.**

# Keep Flutter's embedding entry points.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Billing classes are reached through reflection by the plugin.
-keep class com.android.vending.billing.** { *; }
