# MediaPipe Graph initializes a Flogger logger using stack-based caller lookup.
# Inlining/renaming Flogger breaks that lookup and crashes release camera startup.
-keep class com.google.common.flogger.** { *; }
# The native packet bridge looks up framework fields by their Java names,
# including ProtoUtil.SerializedMessage.typeName and value.
-keep class com.google.mediapipe.framework.ProtoUtil$SerializedMessage { *; }
-keepattributes SourceFile,LineNumberTable,EnclosingMethod,InnerClasses
