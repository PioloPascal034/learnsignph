package com.example.learnsignph

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import androidx.annotation.NonNull
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.ArrayDeque
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val channelName = "com.learnsignph/hand_landmarker"
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val inferenceExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val recognitionLock = Any()
    private var handLandmarker: HandLandmarker? = null
    private var interpreter: Interpreter? = null
    private var labels: List<String> = emptyList()
    private var recognitionMode = "vocabulary"
    private var loadedRecognitionMode = ""
    private val recognitionFrames = ArrayDeque<RecognitionFrame>()
    private val probabilityHistory = ArrayDeque<FloatArray>()
    private var recognitionEnabled = false
    private var inferenceSequence = 0
    private var lastNoHandsMessageAt = 0L
    private var lastCollectingMessageAt = 0L
    private var pendingExportJson: String? = null
    private var pendingExportResult: MethodChannel.Result? = null
    private var channel: MethodChannel? = null
    private var timestamp = 0L
    private var processedFrames = 0

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result -> handleMethod(call, result) }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTracking" -> {
                try {
                    ensureHandLandmarker()
                    ensureRecognitionModel(recognitionMode)
                    synchronized(recognitionLock) {
                        recognitionEnabled = true
                        recognitionFrames.clear()
                        probabilityHistory.clear()
                        inferenceSequence = 0
                        lastCollectingMessageAt = 0
                    }
                    publishPrediction("collecting", "Collecting frames", 0.0, 0)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("RECOGNITION_INIT", error.message, null)
                }
            }
            "setRecognitionMode" -> {
                try {
                    val mode = call.argument<String>("mode") ?: "vocabulary"
                    if (mode != "vocabulary" && mode != "alphabet") {
                        result.error("INVALID_MODE", "Unsupported recognition mode.", null)
                    } else {
                        recognitionMode = mode
                        ensureRecognitionModel(mode)
                        synchronized(recognitionLock) {
                            recognitionFrames.clear()
                            probabilityHistory.clear()
                            inferenceSequence = 0
                        }
                        publishPrediction("collecting", "Collecting frames", 0.0, 0)
                        result.success(null)
                    }
                } catch (error: Exception) {
                    result.error("RECOGNITION_INIT", error.message, null)
                }
            }
            "stopTracking" -> {
                synchronized(recognitionLock) {
                    recognitionEnabled = false
                    recognitionFrames.clear()
                    probabilityHistory.clear()
                }
                closeHandLandmarker()
                result.success(null)
            }
            "resetRecognition" -> {
                synchronized(recognitionLock) {
                    recognitionFrames.clear()
                    probabilityHistory.clear()
                    inferenceSequence = 0
                    lastCollectingMessageAt = 0
                }
                publishPrediction("collecting", "Collecting frames", 0.0, 0)
                result.success(null)
            }
            "loadEvaluationResults" -> {
                val file = File(filesDir, "alphabet_evaluation_results.json")
                result.success(if (file.exists()) file.readText() else "[]")
            }
            "saveEvaluationResults" -> {
                val json = call.argument<String>("json")
                if (json == null) {
                    result.error("INVALID_EVALUATION", "Evaluation JSON was missing.", null)
                } else {
                    val file = File(filesDir, "alphabet_evaluation_results.json")
                    file.writeText(json)
                    result.success(file.absolutePath)
                }
            }
            "exportEvaluationResults" -> {
                val json = call.argument<String>("json")
                if (json == null) {
                    result.error("INVALID_EVALUATION", "Evaluation JSON was missing.", null)
                } else if (pendingExportResult != null) {
                    result.error("EXPORT_BUSY", "An export is already in progress.", null)
                } else {
                    pendingExportJson = json
                    pendingExportResult = result
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, "fsl_alphabet_evaluation.json")
                    }
                    startActivityForResult(intent, evaluationExportRequestCode)
                }
            }
            "processFrame" -> {
                val planes = call.argument<List<Any>>("planes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val rotation = call.argument<Int>("rotation") ?: 0
                if (planes == null || planes.size < 3 || width <= 0 || height <= 0) {
                    result.error("INVALID_FRAME", "Frame bytes were missing.", null)
                } else {
                    processFrame(planes, width, height, rotation)
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureHandLandmarker() {
        if (handLandmarker != null) return
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("hand_landmarker.task")
            .build()
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumHands(2)
            .setMinHandDetectionConfidence(0.5f)
            .setMinHandPresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setResultListener { result, _ ->
                publishResult(result)
                appendRecognitionFrame(result)
            }
            .setErrorListener { error ->
                publishError(error.message ?: "MediaPipe processing failed.")
            }
            .build()
        handLandmarker = HandLandmarker.createFromOptions(this, options)
    }

    private fun ensureRecognitionModel(mode: String) {
        if (interpreter != null && labels.isNotEmpty() && loadedRecognitionMode == mode) return
        interpreter?.close()
        val modelName = if (mode == "alphabet") "alphabet_mlp.tflite" else "transactional_fsl_gru.tflite"
        val labelName = if (mode == "alphabet") "alphabet_label_map.json" else "label_map.json"
        val modelBytes = assets.open(modelName).use { it.readBytes() }
        val modelBuffer = ByteBuffer.allocateDirect(modelBytes.size)
            .order(ByteOrder.nativeOrder())
        modelBuffer.put(modelBytes)
        modelBuffer.rewind()
        interpreter = Interpreter(modelBuffer)

        val labelJson = assets.open(labelName).bufferedReader().use { it.readText() }
        val json = JSONObject(labelJson)
        val parsed = MutableList(json.length()) { "Unknown" }
        json.keys().forEach { label -> parsed[json.getInt(label)] = label }
        labels = parsed
        loadedRecognitionMode = mode
        val inputShape = if (mode == "alphabet") "[1,63]" else "[1,75,126]"
        Log.i("LearnSignPH", "Recognition model loaded: mode=$mode input=$inputShape labels=${labels.size}")
    }

    private fun appendRecognitionFrame(result: HandLandmarkerResult) {
        val features = normalizedRecognitionFeatures(result)
        if (features == null) {
            synchronized(recognitionLock) {
                recognitionFrames.clear()
                probabilityHistory.clear()
                inferenceSequence = 0
            }
            val now = System.currentTimeMillis()
            if (now - lastNoHandsMessageAt > 500) {
                lastNoHandsMessageAt = now
                publishPrediction("no_hands", "No hands detected", 0.0, 0)
            }
            return
        }

        var snapshot: List<RecognitionFrame>? = null
        var frameCount = 0
        synchronized(recognitionLock) {
            if (!recognitionEnabled) return
            recognitionFrames.addLast(RecognitionFrame(System.currentTimeMillis(), features))
            while (recognitionFrames.size > 75) recognitionFrames.removeFirst()
            frameCount = recognitionFrames.size
            inferenceSequence += 1
            val requiredFrames = if (recognitionMode == "alphabet") 1 else 75
            val cadence = if (recognitionMode == "alphabet") 3 else 5
            if (frameCount >= requiredFrames && inferenceSequence % cadence == 0) {
                snapshot = recognitionFrames.toList()
            }
        }

        if (snapshot == null) {
            val now = System.currentTimeMillis()
            if (now - lastCollectingMessageAt > 250) {
                lastCollectingMessageAt = now
                publishPrediction("collecting", "Collecting frames", 0.0, frameCount)
            }
        } else {
            inferenceExecutor.execute { runRecognition(snapshot!!) }
        }
    }

    private fun normalizedRecognitionFeatures(result: HandLandmarkerResult): FloatArray? {
        val output = FloatArray(if (recognitionMode == "alphabet") 63 else 126)
        val assigned = BooleanArray(2)
        var detected = false
        val selectedAlphabetHand = if (recognitionMode == "alphabet") {
            result.landmarks().indices.maxByOrNull { index ->
                result.handedness().getOrNull(index)?.firstOrNull()?.score() ?: 0f
            } ?: 0
        } else -1
        result.landmarks().forEachIndexed { index, landmarks ->
            if (recognitionMode == "alphabet" && index != selectedAlphabetHand) {
                return@forEachIndexed
            }
            if (landmarks.size < 21) return@forEachIndexed
            val category = result.handedness().getOrNull(index)?.firstOrNull()
                ?.categoryName()?.lowercase()
            var slot = when {
                category == "left" -> 0
                category == "right" -> 1
                else -> -1
            }
            if (recognitionMode == "alphabet") {
                slot = 0
            } else if (slot !in 0..1 || assigned[slot]) {
                slot = assigned.indexOfFirst { !it }
            }
            if (slot !in 0..1) return@forEachIndexed
            assigned[slot] = true
            detected = true

            val wrist = landmarks[0]
            val centered = Array(21) { point ->
                floatArrayOf(
                    landmarks[point].x() - wrist.x(),
                    landmarks[point].y() - wrist.y(),
                    landmarks[point].z() - wrist.z(),
                )
            }
            var scale = norm(centered[9])
            if (scale <= 1e-6f) {
                scale = centered.maxOf { norm(it) }
            }
            if (scale <= 1e-6f) return@forEachIndexed
            val offset = slot * 63
            centered.forEachIndexed { landmarkIndex, point ->
                output[offset + landmarkIndex * 3] = point[0] / scale
                output[offset + landmarkIndex * 3 + 1] = point[1] / scale
                output[offset + landmarkIndex * 3 + 2] = point[2] / scale
            }
        }
        return if (detected) output else null
    }

    private fun norm(point: FloatArray): Float =
        sqrt(point[0] * point[0] + point[1] * point[1] + point[2] * point[2])

    private fun runRecognition(frames: List<RecognitionFrame>) {
        try {
            val activeInterpreter = interpreter ?: return
            val input: Any = if (recognitionMode == "alphabet") {
                Array(1) { frames.last().features }
            } else {
                Array(1) { Array(75) { index -> frames[index].features } }
            }
            val output = Array(1) { FloatArray(labels.size) }
            activeInterpreter.run(input, output)

            synchronized(recognitionLock) {
                probabilityHistory.addLast(output[0].copyOf())
                while (probabilityHistory.size > 3) probabilityHistory.removeFirst()
            }
            val averaged = FloatArray(labels.size)
            synchronized(recognitionLock) {
                probabilityHistory.forEach { probabilities ->
                    probabilities.forEachIndexed { index, value -> averaged[index] += value }
                }
            }
            val historySize = synchronized(recognitionLock) { probabilityHistory.size }
            averaged.indices.forEach { averaged[it] /= historySize }
            val bestIndex = averaged.indices.maxByOrNull { averaged[it] } ?: return
            val confidence = averaged[bestIndex]
            val label = if (confidence >= 0.65f) labels[bestIndex] else "Unknown"
            publishPrediction("recognizing", label, confidence.toDouble(), 75)
        } catch (error: Exception) {
            Log.e("LearnSignPH", "Recognition inference failed", error)
            publishError(error.message ?: "Recognition inference failed.")
        }
    }

    private fun publishPrediction(state: String, label: String, confidence: Double, frames: Int) {
        mainHandler.post {
            channel?.invokeMethod("onPrediction", mapOf(
                "state" to state,
                "label" to label,
                "confidence" to confidence,
                "frames" to frames,
            ))
        }
    }

    private fun processFrame(planes: List<Any>, width: Int, height: Int, rotation: Int) {
        executor.execute {
            try {
                ensureHandLandmarker()
                val bytes = yuv420ToJpeg(planes, width, height)
                val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: run {
                        publishError("Camera frame could not be decoded.")
                        Log.w("LearnSignPH", "Unable to decode camera frame (${bytes.size} bytes)")
                        return@execute
                    }
                val bitmap = rotateBitmap(decoded, rotation)
                val image = BitmapImageBuilder(bitmap).build()
                timestamp = maxOf(timestamp + 1, System.currentTimeMillis())
                handLandmarker?.detectAsync(image, timestamp)
                processedFrames += 1
                if (processedFrames % 30 == 0) {
                    Log.d("LearnSignPH", "Submitted $processedFrames camera frames (${decoded.width}x${decoded.height}, rotation=$rotation)")
                }
                if (bitmap !== decoded) decoded.recycle()
                bitmap.recycle()
            } catch (error: Exception) {
                Log.e("LearnSignPH", "Frame processing failed", error)
                publishError(error.message ?: "Frame processing failed.")
            }
        }
    }

    private fun yuv420ToJpeg(planes: List<Any>, width: Int, height: Int): ByteArray {
        val nv21 = ByteArray(width * height * 3 / 2)
        val yPlane = planes[0] as Map<*, *>
        val uPlane = planes[1] as Map<*, *>
        val vPlane = planes[2] as Map<*, *>
        copyPlane(yPlane, width, height, nv21, 0, 1)
        copyChromaPlane(vPlane, width / 2, height / 2, nv21, width * height, uPlane)
        val output = ByteArrayOutputStream()
        YuvImage(nv21, ImageFormat.NV21, width, height, null)
            .compressToJpeg(Rect(0, 0, width, height), 80, output)
        return output.toByteArray()
    }

    private fun copyPlane(
        plane: Map<*, *>, width: Int, height: Int, output: ByteArray,
        outputOffset: Int, outputPixelStride: Int,
    ) {
        val bytes = plane["bytes"] as ByteArray
        val rowStride = (plane["bytesPerRow"] as Number).toInt()
        val pixelStride = (plane["bytesPerPixel"] as Number).toInt()
        var outputIndex = outputOffset
        for (row in 0 until height) {
            val rowStart = row * rowStride
            for (column in 0 until width) {
                output[outputIndex] = bytes[rowStart + column * pixelStride]
                outputIndex += outputPixelStride
            }
        }
    }

    private fun copyChromaPlane(
        firstPlane: Map<*, *>, width: Int, height: Int, output: ByteArray,
        outputOffset: Int, secondPlane: Map<*, *>,
    ) {
        val firstBytes = firstPlane["bytes"] as ByteArray
        val secondBytes = secondPlane["bytes"] as ByteArray
        val firstRowStride = (firstPlane["bytesPerRow"] as Number).toInt()
        val secondRowStride = (secondPlane["bytesPerRow"] as Number).toInt()
        val firstPixelStride = (firstPlane["bytesPerPixel"] as Number).toInt()
        val secondPixelStride = (secondPlane["bytesPerPixel"] as Number).toInt()
        var outputIndex = outputOffset
        for (row in 0 until height) {
            for (column in 0 until width) {
                val firstIndex = row * firstRowStride + column * firstPixelStride
                val secondIndex = row * secondRowStride + column * secondPixelStride
                output[outputIndex++] = firstBytes[firstIndex]
                output[outputIndex++] = secondBytes[secondIndex]
            }
        }
    }

    private fun rotateBitmap(bitmap: Bitmap, rotation: Int): Bitmap {
        val normalized = ((rotation % 360) + 360) % 360
        if (normalized == 0) return bitmap
        val matrix = Matrix().apply { postRotate(normalized.toFloat()) }
        return Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true,
        )
    }

    private fun publishResult(result: HandLandmarkerResult) {
        val hands = result.landmarks().mapIndexed { index, landmarks ->
            val handedness = result.handedness().getOrNull(index)?.firstOrNull()
            mapOf(
                "handedness" to (handedness?.categoryName() ?: "unknown"),
                "score" to (handedness?.score() ?: 0.0f),
                "landmarks" to landmarks.map { landmark ->
                    mapOf(
                        "x" to landmark.x(),
                        "y" to landmark.y(),
                        "z" to landmark.z(),
                    )
                },
            )
        }
        mainHandler.post {
            channel?.invokeMethod("onLandmarks", mapOf("hands" to hands))
        }
    }

    private fun publishError(message: String) {
        mainHandler.post {
            channel?.invokeMethod("onError", message)
        }
    }

    private fun closeHandLandmarker() {
        executor.execute {
            handLandmarker?.close()
            handLandmarker = null
        }
    }

    override fun onDestroy() {
        closeHandLandmarker()
        executor.shutdown()
        interpreter?.close()
        inferenceExecutor.shutdown()
        channel?.setMethodCallHandler(null)
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != evaluationExportRequestCode) return
        val pendingResult = pendingExportResult
        val json = pendingExportJson
        pendingExportResult = null
        pendingExportJson = null
        if (pendingResult == null) return
        if (resultCode != RESULT_OK || data?.data == null || json == null) {
            pendingResult.error("EXPORT_CANCELLED", "Evaluation export was cancelled.", null)
            return
        }
        try {
            contentResolver.openOutputStream(data.data!!).use { output ->
                requireNotNull(output).write(json.toByteArray(Charsets.UTF_8))
            }
            pendingResult.success(data.data.toString())
        } catch (error: Exception) {
            pendingResult.error("EXPORT_FAILED", error.message, null)
        }
    }

    private data class RecognitionFrame(val timestamp: Long, val features: FloatArray)

    companion object {
        private const val evaluationExportRequestCode = 7101
    }
}
