package com.example.demo_nfc

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceLandmark
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.nio.FloatBuffer
import kotlin.math.sqrt

/** OpenCV Zoo SFace, RGB 0..255 NCHW, aligned 112x112, normalized 128-vector. */
class FaceEmbedding(context: Context) : AutoCloseable {
    private val env = OrtEnvironment.getEnvironment()
    private val session = OrtSession.SessionOptions().use { options ->
        options.setIntraOpNumThreads(2)
        env.createSession(context.assets.open("face_recognition_sface_2021dec.onnx").use { it.readBytes() }, options)
    }

    fun extract(bitmap: Bitmap, face: Face): FloatArray {
        fun point(type: Int) = face.getLandmark(type)?.position ?: error("Hãy nhìn thẳng để thấy rõ mắt, mũi và miệng.")
        // Sort landmarks by image x rather than anatomical left/right.
        val eyes = listOf(point(FaceLandmark.LEFT_EYE), point(FaceLandmark.RIGHT_EYE)).sortedBy { it.x }
        val mouth = listOf(point(FaceLandmark.MOUTH_LEFT), point(FaceLandmark.MOUTH_RIGHT)).sortedBy { it.x }
        val src = listOf(eyes[0], eyes[1], point(FaceLandmark.NOSE_BASE), mouth[0], mouth[1])
        val dst = arrayOf(floatArrayOf(38.2946f,51.6963f), floatArrayOf(73.5318f,51.5014f),
            floatArrayOf(56.0252f,71.7366f), floatArrayOf(41.5493f,92.3655f), floatArrayOf(70.7299f,92.2041f))
        val sx = src.map { it.x }.average(); val sy = src.map { it.y }.average()
        val dx = dst.map { it[0] }.average(); val dy = dst.map { it[1] }.average()
        var den = 0.0; var a = 0.0; var b = 0.0
        for (i in 0..4) {
            val x = src[i].x-sx; val y = src[i].y-sy
            val u = dst[i][0]-dx; val v = dst[i][1]-dy
            den += x*x+y*y; a += x*u+y*v; b += x*v-y*u
        }
        require(den > 1) { "Khuôn mặt quá nhỏ." }
        a /= den; b /= den
        val matrix = Matrix().apply { setValues(floatArrayOf(a.toFloat(), -b.toFloat(), (dx-a*sx+b*sy).toFloat(),
            b.toFloat(), a.toFloat(), (dy-b*sx-a*sy).toFloat(), 0f,0f,1f)) }
        val aligned = Bitmap.createBitmap(112,112,Bitmap.Config.ARGB_8888)
        Canvas(aligned).drawBitmap(bitmap,matrix,Paint(Paint.FILTER_BITMAP_FLAG))
        val pixels = IntArray(112*112)
        aligned.getPixels(pixels,0,112,0,0,112,112)
        aligned.recycle()
        val input = FloatArray(pixels.size*3)
        pixels.forEachIndexed { i,p ->
            input[i] = ((p shr 16) and 255).toFloat()
            input[i+pixels.size] = ((p shr 8) and 255).toFloat()
            input[i+pixels.size*2] = (p and 255).toFloat()
        }
        return OnnxTensor.createTensor(env,FloatBuffer.wrap(input),longArrayOf(1,3,112,112)).use { tensor ->
            session.run(mapOf(session.inputNames.first() to tensor)).use { result ->
                val feature = (result[0].value as Array<*>)[0] as FloatArray
                require(feature.size == 128)
                val norm = sqrt(feature.sumOf { it.toDouble()*it })
                require(norm > 0 && norm.isFinite())
                FloatArray(128) { (feature[it]/norm).toFloat() }
            }
        }
    }
    override fun close() = session.close()
}
