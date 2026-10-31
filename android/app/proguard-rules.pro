# ML Kit discovers these manifest-registered components using reflection.
# R8 full mode otherwise removes their no-argument constructors in release.
-keep class com.google.mlkit.common.internal.CommonComponentRegistrar {
    public <init>();
}
-keep class com.google.mlkit.vision.common.internal.VisionCommonRegistrar {
    public <init>();
}
-keep class com.google.mlkit.vision.face.internal.FaceRegistrar {
    public <init>();
}

# ONNX JNI looks up Java tensor metadata and result classes by their full names.
# https://onnxruntime.ai/docs/build/android.html
-keep class ai.onnxruntime.** { *; }
