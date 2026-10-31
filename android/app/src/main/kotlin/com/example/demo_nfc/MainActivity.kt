package com.example.demo_nfc

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var cameraResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "attendance/face_camera")
            .setMethodCallHandler { call, result ->
                if (call.method != "capture") {
                    result.notImplemented()
                } else if (cameraResult != null) {
                    result.error("CAMERA_BUSY", "Camera đang được sử dụng.", null)
                } else {
                    cameraResult = result
                    try {
                        startActivityForResult(Intent(this, FaceCameraActivity::class.java)
                            .putExtra("purpose", call.argument<String>("purpose") ?: "enroll")
                            .putExtra("turnFirst", call.argument<Boolean>("turnFirst") ?: false), 8041)
                    } catch (e: Exception) {
                        cameraResult = null
                        result.error("CAMERA_ERROR", e.message, null)
                    }
                }
            }
    }

    @Deprecated("Activity result bridge for the Flutter method channel")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 8041) return
        val result = cameraResult ?: return
        cameraResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.error("FACE_CANCELLED", data?.getStringExtra("error") ?: "Đã hủy xác thực khuôn mặt.", null)
            return
        }
        val first = data?.getFloatArrayExtra("first")
        val last = data?.getFloatArrayExtra("last")
        if (first == null || last == null) {
            result.error("FACE_ERROR", "Không lấy được đặc trưng khuôn mặt.", null)
        } else {
            result.success(mapOf("first" to first.map { it.toDouble() },
                "last" to last.map { it.toDouble() }, "model" to "sface-2021dec-v1"))
        }
    }
}
