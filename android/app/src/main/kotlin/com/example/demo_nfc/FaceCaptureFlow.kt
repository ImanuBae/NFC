package com.example.demo_nfc

import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/** Camera-independent capture decisions, driven by monotonic frame timestamps. */
internal class FaceCaptureFlow(private val gestures: Boolean, turnFirst: Boolean) {
    enum class Step { ALIGN, BLINK, TURN, FINAL }
    enum class Capture { FIRST, LAST }
    data class Bounds(val left: Float, val top: Float, val right: Float, val bottom: Float) {
        val width get() = right - left
        val height get() = bottom - top
        val area get() = max(0f, width) * max(0f, height)
        private fun intersection(other: Bounds) = max(0f, min(right, other.right) - max(left, other.left)) *
            max(0f, min(bottom, other.bottom) - max(top, other.top))
        val visibleFraction get() = if (area > 0) intersection(Bounds(0f, 0f, 1f, 1f)) / area else 0f
        fun continuousWith(other: Bounds): Boolean {
            val intersection = intersection(other)
            val union = area + other.area - intersection
            val distance = hypot((left + right - other.left - other.right) / 2, (top + bottom - other.top - other.bottom) / 2)
            val ratio = if (other.area > 0) area / other.area else 0f
            return (union > 0 && intersection / union >= .25f) || (distance < .16f && ratio in .5f..2f)
        }
    }
    data class Observation(
        val bounds: Bounds, val yaw: Float = 0f, val roll: Float = 0f, val pitch: Float = 0f,
        val leftEye: Float? = .9f, val rightEye: Float? = .9f,
        val trackingId: Int? = 1, val landmarksVisible: Boolean = true, val facePixels: Int = 160,
    )
    data class Update(val message: String, val capture: Capture? = null, val restarted: Boolean = false, val immediate: Boolean = false)

    private val steps = if (!gestures) listOf(Step.ALIGN, Step.FINAL)
        else listOf(Step.ALIGN, if (turnFirst) Step.TURN else Step.BLINK, if (turnFirst) Step.BLINK else Step.TURN, Step.FINAL)
    private var index = 0
    val step get() = steps[index]
    private var missingSince: Long? = null
    private var holdSince: Long? = null
    private var holdFrames = 0
    private var closedAt: Long? = null
    private var turnSince: Long? = null
    private var turnFrames = 0
    private var turned = false
    private var previous: Observation? = null

    private fun feedback(text: String, capture: Capture? = null, immediate: Boolean = false) =
        Update("Bước ${index + 1}/${steps.size}: $text", capture, immediate = immediate)

    fun restart(text: String): Update {
        index = 0; missingSince = null; previous = null
        clearStep()
        return Update("Bước 1/${steps.size}: $text", restarted = true, immediate = true)
    }

    private fun clearStep() {
        holdSince = null; holdFrames = 0; closedAt = null
        turnSince = null; turnFrames = 0; turned = false
    }

    private fun advance(): Update {
        index++; clearStep()
        return feedback(instruction(), immediate = true)
    }

    fun capturedFirst(): Update = advance()
    private fun instruction() = when (step) {
        Step.ALIGN, Step.FINAL -> "Nhìn thẳng và giữ yên để lấy mẫu."
        Step.BLINK -> "Chớp mắt một lần, sau đó mở mắt bình thường."
        Step.TURN -> "Quay nhẹ đầu sang một bên."
    }

    private fun interrupted(now: Long, text: String): Update {
        holdSince = null; holdFrames = 0
        val since = missingSince ?: now.also { missingSince = it }
        // Webcam tracking can briefly disappear while blinking or turning.
        // Retain the gesture only through a short gap, never through a long absence.
        return if (now - since >= 1200) restart(text) else feedback(text)
    }

    fun update(now: Long, faces: List<Observation>): Update {
        if (faces.size > 1) return restart("Chỉ để một người trong khung hình.")
        if (faces.isEmpty()) return interrupted(now, "Đưa khuôn mặt trở lại khung hình để tiếp tục.")
        val absentSince = missingSince
        if (absentSince != null && now - absentSince >= 1200)
            return restart("Nhìn thẳng để bắt đầu lại sau khi mất dấu khuôn mặt.")
        val face = faces.single()
        if (face.facePixels < 100 || face.bounds.width < .18f)
            return interrupted(now, "Tiến gần camera hơn một chút để thấy rõ khuôn mặt.")
        val sampleStep = step == Step.ALIGN || step == Step.FINAL
        if (face.bounds.visibleFraction < if (sampleStep) .90f else .80f)
            return interrupted(now, "Lùi nhẹ ra xa và đưa khuôn mặt vào giữa khung hình.")

        val old = previous
        if (old != null && old.trackingId != null && face.trackingId != null &&
            old.trackingId != face.trackingId && !face.bounds.continuousWith(old.bounds))
            return restart("Khuôn mặt đã thay đổi. Nhìn thẳng để bắt đầu lại.")
        previous = face
        missingSince = null
        val frontal = abs(face.yaw) < 15 && abs(face.roll) < 15 && abs(face.pitch) < 20
        val left = face.leftEye
        val right = face.rightEye

        if (sampleStep) {
            if (!frontal || !face.landmarksVisible || (gestures && (left == null || right == null || left < .55f || right < .55f))) {
                holdSince = null; holdFrames = 0
                return feedback("Nhìn thẳng, để rõ hai mắt và giữ yên điện thoại.")
            }
            val since = holdSince ?: now.also { holdSince = it }
            holdFrames++
            if (holdFrames < 3 || now - since < 250) return feedback("Giữ yên, đang chuẩn bị lấy mẫu…")
            return feedback("Đang lấy mẫu khuôn mặt…", if (step == Step.ALIGN) Capture.FIRST else Capture.LAST, immediate = true)
        }

        if (step == Step.TURN) {
            if (!turned && abs(face.yaw) >= 18) {
                val since = turnSince ?: now.also { turnSince = it }
                turnFrames++
                if (turnFrames >= 2 && now - since >= 80) turned = true
            } else if (!turned) { turnSince = null; turnFrames = 0 }
            if (turned && frontal) return advance()
            return feedback(if (turned) "Đã nhận quay đầu. Nhìn thẳng lại camera." else instruction(), immediate = turned)
        }

        if (!frontal || left == null || right == null) return feedback("Nhìn thẳng để camera thấy rõ hai mắt.")
        val closed = closedAt
        if (closed != null && now - closed > 1500) closedAt = null
        if (closedAt == null && left < .35f && right < .35f) closedAt = now
        val blink = closedAt
        if (blink != null && now - blink in 50..1500 && left > .55f && right > .55f) return advance()
        return feedback(if (blink != null) "Đã nhận nhắm mắt. Mở mắt bình thường." else instruction())
    }
}
