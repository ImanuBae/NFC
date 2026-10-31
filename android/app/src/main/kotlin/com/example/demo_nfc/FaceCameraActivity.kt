package com.example.demo_nfc

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Size
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.fragment.app.FragmentActivity
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.min

class FaceCameraActivity : FragmentActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private val detector = FaceDetection.getClient(FaceDetectorOptions.Builder()
        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
        .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
        .enableTracking().build())
    private var embedding: FaceEmbedding? = null
    private var provider: ProcessCameraProvider? = null
    private lateinit var preview: PreviewView
    private lateinit var message: TextView
    private var first: FloatArray? = null
    private lateinit var flow: FaceCaptureFlow
    private var displayedText: String? = null
    private var candidateText: String? = null
    private var candidateAt = 0L
    private var lastFrame = 0L
    private var requiresGestures = true
    @Volatile private var stopped = false
    private val timeout = Runnable { cancel("Hết thời gian. Hãy thử lại ở nơi đủ sáng.") }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Missing/unknown purposes retain the stricter enrollment flow.
        requiresGestures = intent.getStringExtra("purpose") !in listOf("check_in", "check_out")
        flow = FaceCaptureFlow(requiresGestures, intent.getBooleanExtra("turnFirst", false))
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.rgb(230, 225, 245))
        }
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val safe = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(safe.left + dp(16), safe.top + dp(16), safe.right + dp(16), safe.bottom + dp(16))
            insets
        }
        message = TextView(this).apply {
            setTextColor(Color.rgb(48, 32, 71))
            textSize = 18f
            minLines = 3
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = GradientDrawable().apply {
                setColor(Color.rgb(216, 199, 255))
                cornerRadius = dp(20).toFloat()
            }
            text=if(requiresGestures)
                "Đăng ký mẫu: đưa một khuôn mặt vào giữa camera và làm theo hướng dẫn."
            else "Chấm công: nhìn thẳng vào camera và giữ yên trong giây lát. Không cần chớp mắt hay quay đầu." }
        preview = PreviewView(this).apply {
            setBackgroundColor(Color.BLACK)
            // Show the whole camera frame, including landscape laptop webcams.
            // TextureView also avoids emulator SurfaceView clipping/transform issues.
            scaleType = PreviewView.ScaleType.FIT_CENTER
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        }
        val cancel = Button(this).apply {
            text = "Hủy"
            isAllCaps = false
            minHeight = dp(48)
            setOnClickListener { cancel("Đã hủy xác thực khuôn mặt.") }
        }
        root.addView(message, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(16) })
        root.addView(preview,LinearLayout.LayoutParams(-1,0,1f))
        root.addView(cancel)
        setContentView(root)
        // Some Android builds have no DecorView until setContentView installs it.
        // Initialize system-bar appearance only after the window content exists.
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = true
            isAppearanceLightNavigationBars = true
        }
        ViewCompat.requestApplyInsets(root)
        if (ContextCompat.checkSelfPermission(this,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED) start()
        else ActivityCompat.requestPermissions(this,arrayOf(Manifest.permission.CAMERA),42)
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(code,permissions,grants)
        if (code==42 && grants.firstOrNull()==PackageManager.PERMISSION_GRANTED) start()
        else cancel("Cần cho phép camera để đăng ký/chấm công bằng khuôn mặt.")
    }

    private fun start() {
        handler.postDelayed(timeout,75000)
        // Load SFace on the analyzer thread while the user positions their face.
        executor.execute {
            try {
                if (!stopped) embedding = FaceEmbedding(this)
            } catch (e: Exception) {
                runOnUiThread { cancel("Không khởi tạo được bộ nhận diện. Hãy mở lại camera.") }
            }
        }
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            try {
                if (stopped) return@addListener
                provider=future.get()
                val p=Preview.Builder().build().also { it.surfaceProvider=preview.surfaceProvider }
                val analysis=ImageAnalysis.Builder()
                    .setResolutionSelector(ResolutionSelector.Builder()
                        .setResolutionStrategy(ResolutionStrategy(Size(640, 480),
                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER)).build())
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(executor) { image ->
                    if (stopped || SystemClock.elapsedRealtime()-lastFrame<80) { image.close(); return@setAnalyzer }
                    lastFrame=SystemClock.elapsedRealtime()
                    var bitmap: Bitmap? = null
                    try {
                        val raw=image.toBitmap()
                        val rotation=image.imageInfo.rotationDegrees
                        bitmap=if(rotation==0) raw else Bitmap.createBitmap(raw,0,0,raw.width,raw.height,
                            Matrix().apply { postRotate(rotation.toFloat()) },true).also { raw.recycle() }
                        val frame=bitmap
                        // Synchronous wait keeps one frame in flight and cleanup on the same executor.
                        val faces=com.google.android.gms.tasks.Tasks.await(detector.process(InputImage.fromBitmap(frame,0)),5,TimeUnit.SECONDS)
                        if (!stopped) process(frame,faces)
                    } catch(e:Exception) {
                        if (!stopped) show(e.message ?: "Không đọc được khuôn mặt. Hãy thử lại.")
                    } finally { bitmap?.recycle(); image.close() }
                }
                provider!!.bindToLifecycle(this,CameraSelector.DEFAULT_FRONT_CAMERA,p,analysis)
            } catch(e:Exception) { cancel("Không mở được camera trước: ${e.message}") }
        },ContextCompat.getMainExecutor(this))
    }

    private fun show(text: String, immediate: Boolean = false) {
        val now = SystemClock.elapsedRealtime()
        if (candidateText != text) { candidateText = text; candidateAt = now }
        if ((!immediate && now - candidateAt < 200) || displayedText == text) return
        displayedText = text
        runOnUiThread { if (!stopped) message.text = text }
    }
    private fun process(bitmap: Bitmap, faces: List<Face>) {
        val observations = faces.map { face ->
            val box = face.boundingBox
            val landmarksVisible = listOf(FaceLandmark.LEFT_EYE, FaceLandmark.RIGHT_EYE,
                FaceLandmark.NOSE_BASE, FaceLandmark.MOUTH_LEFT, FaceLandmark.MOUTH_RIGHT).all { type ->
                val point = face.getLandmark(type)?.position
                point != null && point.x >= 0 && point.x < bitmap.width && point.y >= 0 && point.y < bitmap.height
            }
            FaceCaptureFlow.Observation(
                bounds = FaceCaptureFlow.Bounds(box.left.toFloat() / bitmap.width, box.top.toFloat() / bitmap.height,
                    box.right.toFloat() / bitmap.width, box.bottom.toFloat() / bitmap.height),
                yaw = face.headEulerAngleY, roll = face.headEulerAngleZ, pitch = face.headEulerAngleX,
                leftEye = face.leftEyeOpenProbability, rightEye = face.rightEyeOpenProbability,
                trackingId = face.trackingId, landmarksVisible = landmarksVisible,
                facePixels = min(box.width(), box.height()),
            )
        }
        val update = flow.update(SystemClock.elapsedRealtime(), observations)
        if (update.restarted) first = null
        show(update.message, update.immediate)
        if (update.capture == null) return
        val vector = (embedding ?: error("Bộ nhận diện chưa sẵn sàng.")).extract(bitmap, faces.single())
        if (update.capture == FaceCaptureFlow.Capture.FIRST) {
            first = vector
            val next = flow.capturedFirst()
            show(next.message, true)
            return
        }
        val initial = first ?: return
        val similarity = initial.indices.sumOf { initial[it].toDouble() * vector[it] }
        if (similarity < .45) {
            first = null
            val reset = flow.restart("Hai mẫu chưa nhất quán. Nhìn thẳng và thử lại.")
            show(reset.message, true)
            return
        }
        stopped = true
        runOnUiThread {
            setResult(Activity.RESULT_OK, Intent().putExtra("first", initial).putExtra("last", vector))
            finish()
        }
    }

    private fun cancel(error:String) {
        if(stopped) return
        stopped=true
        setResult(Activity.RESULT_CANCELED,Intent().putExtra("error",error)); finish()
    }
    override fun onDestroy() {
        stopped=true; handler.removeCallbacks(timeout); provider?.unbindAll()
        executor.execute { detector.close(); embedding?.close() }
        executor.shutdown()
        super.onDestroy()
    }
}
