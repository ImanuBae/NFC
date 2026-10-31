package com.example.demo_nfc

import org.junit.Assert.*
import org.junit.Test

class FaceCaptureFlowTest {
    private val face = FaceCaptureFlow.Observation(FaceCaptureFlow.Bounds(.25f, .15f, .75f, .85f))
    private fun frame(flow: FaceCaptureFlow, time: Long, observation: FaceCaptureFlow.Observation = face) =
        flow.update(time, listOf(observation))
    private fun first(flow: FaceCaptureFlow) {
        assertNull(frame(flow, 0).capture)
        assertNull(frame(flow, 100).capture)
        assertEquals(FaceCaptureFlow.Capture.FIRST, frame(flow, 300).capture)
        flow.capturedFirst()
    }

    @Test fun completeEnrollmentRequiresBlinkTurnReturnAndSecondSample() {
        val flow = FaceCaptureFlow(true, false)
        first(flow)
        assertEquals(FaceCaptureFlow.Step.BLINK, flow.step)
        frame(flow, 400, face.copy(leftEye = .1f, rightEye = .1f))
        frame(flow, 480)
        assertEquals(FaceCaptureFlow.Step.TURN, flow.step)
        frame(flow, 600, face.copy(yaw = 22f))
        val turned = frame(flow, 700, face.copy(yaw = 24f))
        assertTrue(turned.message.contains("Nhìn thẳng lại"))
        assertEquals(FaceCaptureFlow.Step.TURN, flow.step)
        frame(flow, 800)
        assertEquals(FaceCaptureFlow.Step.FINAL, flow.step)
        assertNull(frame(flow, 900).capture)
        assertNull(frame(flow, 1000).capture)
        assertEquals(FaceCaptureFlow.Capture.LAST, frame(flow, 1200).capture)
    }

    @Test fun challengeCanRequireTurnBeforeBlink() {
        val flow = FaceCaptureFlow(true, true)
        first(flow)
        assertEquals(FaceCaptureFlow.Step.TURN, flow.step)
        frame(flow, 400, face.copy(yaw = -22f))
        frame(flow, 500, face.copy(yaw = -24f))
        frame(flow, 600)
        assertEquals(FaceCaptureFlow.Step.BLINK, flow.step)
        frame(flow, 700, face.copy(leftEye = .1f, rightEye = .1f))
        frame(flow, 800)
        assertEquals(FaceCaptureFlow.Step.FINAL, flow.step)
    }

    @Test fun aShortWebcamDropoutPreservesCurrentGesture() {
        val flow = FaceCaptureFlow(true, false)
        first(flow)
        assertFalse(flow.update(400, emptyList()).restarted)
        assertFalse(frame(flow, 700).restarted)
        assertEquals(FaceCaptureFlow.Step.BLINK, flow.step)
    }

    @Test fun aLongAbsenceResetsEvenIfTheNextFrameIsValid() {
        val flow = FaceCaptureFlow(true, false)
        first(flow)
        flow.update(400, emptyList())
        assertTrue(frame(flow, 1700).restarted)
        assertEquals(FaceCaptureFlow.Step.ALIGN, flow.step)
    }

    @Test fun persistentMissingFramesResetProgress() {
        val flow = FaceCaptureFlow(true, false)
        first(flow)
        flow.update(400, emptyList())
        assertTrue(flow.update(1700, emptyList()).restarted)
    }

    @Test fun trackerRenumberingAtTheSamePositionDoesNotRestart() {
        val flow = FaceCaptureFlow(true, false)
        first(flow)
        assertFalse(frame(flow, 400, face.copy(trackingId = 8)).restarted)
        assertEquals(FaceCaptureFlow.Step.BLINK, flow.step)
    }

    @Test fun trackerChangeWithSpatialJumpResets() {
        val flow = FaceCaptureFlow(true, false)
        val small = face.copy(bounds = FaceCaptureFlow.Bounds(.05f, .2f, .3f, .7f))
        frame(flow, 0, small); frame(flow, 100, small); frame(flow, 300, small)
        flow.capturedFirst()
        assertTrue(frame(flow, 400, small.copy(trackingId = 8,
            bounds = FaceCaptureFlow.Bounds(.7f, .2f, .95f, .7f))).restarted)
    }

    @Test fun anotherVisiblePersonResetsImmediately() {
        val flow = FaceCaptureFlow(true, false)
        first(flow)
        assertTrue(flow.update(400, listOf(face, face.copy(trackingId = 2))).restarted)
        assertEquals(FaceCaptureFlow.Step.ALIGN, flow.step)
    }

    @Test fun slightBoundingBoxOvershootWithVisibleLandmarksIsAccepted() {
        val flow = FaceCaptureFlow(true, false)
        val clipped = face.copy(bounds = FaceCaptureFlow.Bounds(.2f, -.02f, .8f, .8f))
        frame(flow, 0, clipped); frame(flow, 100, clipped)
        assertEquals(FaceCaptureFlow.Capture.FIRST, frame(flow, 300, clipped).capture)
    }

    @Test fun cropAndDistanceHaveOppositeUsefulGuidance() {
        val flow = FaceCaptureFlow(true, false)
        assertTrue(frame(flow, 0, face.copy(facePixels = 70)).message.contains("Tiến gần"))
        val clipped = face.copy(bounds = FaceCaptureFlow.Bounds(-.3f, -.3f, 1.3f, 1.3f))
        assertTrue(frame(flow, 100, clipped).message.contains("Lùi nhẹ"))
    }

    @Test fun missingLandmarksOrEyeProbabilitiesCannotProduceEnrollmentSamples() {
        val flow = FaceCaptureFlow(true, false)
        repeat(6) { i -> assertNull(frame(flow, i * 100L, face.copy(landmarksVisible = false)).capture) }
        repeat(6) { i -> assertNull(frame(flow, 1000 + i * 100L, face.copy(leftEye = null)).capture) }
    }

    @Test fun openingEyesWithoutAClosureCannotCompleteBlink() {
        val flow = FaceCaptureFlow(true, false)
        first(flow)
        frame(flow, 400); frame(flow, 500); frame(flow, 600)
        assertEquals(FaceCaptureFlow.Step.BLINK, flow.step)
        frame(flow, 700, face.copy(leftEye = .1f, rightEye = .1f))
        frame(flow, 2300)
        assertEquals(FaceCaptureFlow.Step.BLINK, flow.step)
    }

    @Test fun missingClassificationProducesGuidanceInsteadOfSilentFailure() {
        val flow = FaceCaptureFlow(true, false)
        first(flow)
        assertTrue(frame(flow, 400, face.copy(leftEye = null)).message.contains("hai mắt"))
        assertEquals(FaceCaptureFlow.Step.BLINK, flow.step)
    }

    @Test fun aSingleTurnSpikeCannotCompleteTheTurn() {
        val flow = FaceCaptureFlow(true, true)
        first(flow)
        frame(flow, 400, face.copy(yaw = 24f)); frame(flow, 500)
        assertEquals(FaceCaptureFlow.Step.TURN, flow.step)
    }

    @Test fun kioskStillRequiresTwoStableSamplesButNoGesturesOrEyeClassification() {
        val flow = FaceCaptureFlow(false, false)
        first(flow)
        assertEquals(FaceCaptureFlow.Step.FINAL, flow.step)
        val unclassified = face.copy(leftEye = null, rightEye = null)
        frame(flow, 400, unclassified); frame(flow, 500, unclassified)
        assertEquals(FaceCaptureFlow.Capture.LAST, frame(flow, 700, unclassified).capture)
    }

    @Test fun callerCanRestartAfterEmbeddingMismatch() {
        val flow = FaceCaptureFlow(true, false)
        first(flow)
        assertTrue(flow.restart("Không nhất quán").restarted)
        assertEquals(FaceCaptureFlow.Step.ALIGN, flow.step)
        assertNull(frame(flow, 400).capture)
    }
}
