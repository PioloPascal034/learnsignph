import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';

class LivePracticeScreen extends StatefulWidget {
  final bool isActive;

  const LivePracticeScreen({super.key, this.isActive = true});

  @override
  State<LivePracticeScreen> createState() => _LivePracticeScreenState();
}

class _LivePracticeScreenState extends State<LivePracticeScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.learnsignph/hand_landmarker');

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  int _initializationToken = 0;
  bool _isInitializing = false;
  bool _isProcessingFrame = false;
  bool _isTracking = true;
  String? _errorMessage;
  List<DetectedHand> _hands = const [];
  List<String> _availableSigns = const [];
  String? _targetSign;
  String _recognitionMode = 'vocabulary';
  String _guidedFeedback = 'Select a target sign to begin practice.';
  int _consistentTargetPredictions = 0;
  String _recognitionState = 'collecting';
  String _predictionLabel = 'Collecting frames';
  double _predictionConfidence = 0;
  int _recognitionFrames = 0;
  bool _evaluationMode = false;
  Timer? _evaluationTimer;
  DateTime? _evaluationStartedAt;
  final List<_EvaluationSample> _evaluationSamples = [];
  final List<AlphabetEvaluationRecord> _evaluationRecords = [];
  AlphabetEvaluationRecord? _lastEvaluationRecord;
  String? _evaluationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeMessage);
    _loadSignLabels(_recognitionMode);
    _loadEvaluationResults();
    if (widget.isActive) _initializeCamera();
  }

  Future<void> _loadSignLabels(String mode) async {
    try {
      final asset = mode == 'alphabet'
          ? 'assets/ml_models/alphabet_label_map.json'
          : 'assets/ml_models/label_map.json';
      final raw = await rootBundle.loadString(asset);
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final labels = decoded.entries.toList()
        ..sort((a, b) => (a.value as num).compareTo(b.value as num));
      if (!mounted) return;
      setState(() {
        _availableSigns = labels.map((entry) => entry.key).toList();
        _targetSign ??= _availableSigns.isEmpty ? null : _availableSigns.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableSigns = mode == 'alphabet'
            ? const [
                'A',
                'B',
                'C',
                'D',
                'E',
                'F',
                'G',
                'H',
                'I',
                'K',
                'L',
                'M',
                'N',
                'O',
                'P',
                'Q',
                'R',
                'S',
                'T',
                'U',
                'V',
                'W',
                'X',
                'Y',
              ]
            : const [
                'AGAIN',
                'CARD',
                'CASH',
                'COIN',
                'DISCOUNT',
                'EIGHT',
                'FIVE',
                'FOUR',
                'HELLO',
                'HOW_MANY',
                'HOW_MUCH',
                'NINE',
                'NO',
                'ONE',
                'PLEASE',
                'PROBLEM',
                'RECEIPT',
                'SEVEN',
                'SIX',
                'TEN',
                'THANK_YOU',
                'THREE',
                'TWO',
                'WAIT',
                'WELCOME',
                'YES',
              ];
        _targetSign ??= _availableSigns.first;
      });
    }
  }

  @override
  void didUpdateWidget(covariant LivePracticeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initializeCamera();
    } else if (!widget.isActive && oldWidget.isActive) {
      _disposeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final token = ++_initializationToken;
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });
    try {
      final cameras = await availableCameras();
      if (!mounted || token != _initializationToken || cameras.isEmpty) return;
      final shouldSelectPreferredCamera = _cameras.isEmpty;
      _cameras = cameras;
      if (shouldSelectPreferredCamera || _cameraIndex >= cameras.length) {
        _cameraIndex = _preferredCameraIndex(cameras);
      }
      final controller = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted || token != _initializationToken) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await _channel.invokeMethod<void>('startTracking');
      await controller.startImageStream(_onCameraFrame);
      setState(() => _isInitializing = false);
    } on CameraException catch (error) {
      if (!mounted || token != _initializationToken) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = _cameraErrorMessage(error);
      });
    } on PlatformException catch (error) {
      if (!mounted || token != _initializationToken) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = error.message ?? 'Hand tracking could not start.';
      });
    } catch (error) {
      if (!mounted || token != _initializationToken) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Camera could not be initialized: $error';
      });
    }
  }

  int _preferredCameraIndex(List<CameraDescription> cameras) {
    final front = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);
    return front >= 0 ? front : 0;
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (!_isTracking || _isProcessingFrame || _controller == null) return;
    if (image.planes.length < 3) return;
    _isProcessingFrame = true;
    try {
      await _channel.invokeMethod<void>('processFrame', {
        'planes': image.planes
            .map((plane) => <String, dynamic>{
                  'bytes': plane.bytes,
                  'bytesPerRow': plane.bytesPerRow,
                  'bytesPerPixel': plane.bytesPerPixel ?? 1,
                })
            .toList(),
        'width': image.width,
        'height': image.height,
        'rotation': _controller!.description.sensorOrientation,
      });
    } catch (error) {
      if (mounted) setState(() => _errorMessage = 'Tracking error: $error');
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _handleNativeMessage(MethodCall call) async {
    if (!mounted) return;
    if (call.method == 'onLandmarks') {
      final data = Map<String, dynamic>.from(call.arguments as Map);
      final rawHands = data['hands'] as List<dynamic>? ?? const [];
      setState(() {
        _hands = rawHands
            .map((hand) =>
                DetectedHand.fromMap(Map<String, dynamic>.from(hand as Map)))
            .toList();
        _errorMessage = null;
      });
    } else if (call.method == 'onPrediction') {
      final data = Map<String, dynamic>.from(call.arguments as Map);
      final state = data['state']?.toString() ?? 'collecting';
      final label = data['label']?.toString() ?? 'Unknown';
      final confidence = (data['confidence'] as num?)?.toDouble() ?? 0;
      _updateGuidedFeedback(state, label, confidence);
      _handleEvaluationPrediction(state, label, confidence);
      setState(() {
        _recognitionState = state;
        _predictionLabel = label;
        _predictionConfidence = confidence;
        _recognitionFrames = (data['frames'] as num?)?.toInt() ?? 0;
      });
    } else if (call.method == 'onError') {
      setState(() => _errorMessage = call.arguments?.toString());
    }
  }

  Future<void> _loadEvaluationResults() async {
    try {
      final raw = await _channel.invokeMethod<String>('loadEvaluationResults');
      if (!mounted || raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      setState(() {
        _evaluationRecords
          ..clear()
          ..addAll(decoded.map((item) => AlphabetEvaluationRecord.fromMap(
              Map<String, dynamic>.from(item as Map))));
      });
    } catch (_) {
      // A first run has no local evaluation file yet.
    }
  }

  void _handleEvaluationPrediction(
      String state, String label, double confidence) {
    if (!_evaluationMode || _recognitionMode != 'alphabet') return;
    if (state == 'no_hands') return;
    if (state != 'recognizing') return;
    if (_evaluationStartedAt == null) {
      _evaluationStartedAt = DateTime.now();
      _evaluationSamples.clear();
      _lastEvaluationRecord = null;
      _evaluationTimer?.cancel();
      _evaluationTimer =
          Timer(const Duration(seconds: 2), _finishEvaluationAttempt);
      _evaluationMessage = 'Collecting evaluation predictions...';
    }
    _evaluationSamples.add(_EvaluationSample(label, confidence));
    if (DateTime.now().difference(_evaluationStartedAt!).inMilliseconds >=
        2000) {
      _finishEvaluationAttempt();
    }
  }

  void _finishEvaluationAttempt() {
    _evaluationTimer?.cancel();
    _evaluationTimer = null;
    final target = _targetSign;
    if (target == null) return;
    final samples = List<_EvaluationSample>.from(_evaluationSamples);
    final validSamples = samples.where((sample) => sample.label != 'Unknown');
    final counts = <String, int>{};
    for (final sample in validSamples) {
      counts[sample.label] = (counts[sample.label] ?? 0) + 1;
    }
    String? predicted;
    if (counts.isNotEmpty) {
      predicted =
          counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    final averageConfidence = samples.isEmpty
        ? 0.0
        : samples.map((sample) => sample.confidence).reduce((a, b) => a + b) /
            samples.length;
    final result = predicted == null
        ? 'untested'
        : predicted == target
            ? 'match'
            : 'mismatch';
    final record = AlphabetEvaluationRecord(
      targetLetter: target,
      predictedLetter: predicted,
      averageConfidence: averageConfidence,
      predictionCount: samples.length,
      result: result,
      timestamp: DateTime.now().toUtc(),
    );
    if (!mounted) return;
    setState(() {
      _lastEvaluationRecord = record;
      _evaluationStartedAt = null;
      _evaluationMessage = result == 'untested'
          ? 'Untested: no valid letter prediction was received.'
          : result == 'match'
              ? 'Model agreement with target. This is not proof of correct FSL execution.'
              : 'Model predicted a different letter.';
    });
  }

  Future<void> _toggleEvaluation(bool enabled) async {
    if (_recognitionMode != 'alphabet') return;
    _evaluationTimer?.cancel();
    _evaluationStartedAt = null;
    _evaluationSamples.clear();
    setState(() {
      _evaluationMode = enabled;
      _lastEvaluationRecord = null;
      _evaluationMessage =
          enabled ? 'Show the target handshape to begin.' : null;
    });
    if (!enabled) await _resetPractice();
  }

  Future<void> _saveEvaluationResult() async {
    final record = _lastEvaluationRecord;
    if (record == null) return;
    if (!_evaluationRecords.any((item) => item.timestamp == record.timestamp)) {
      _evaluationRecords.add(record);
    }
    final json =
        jsonEncode(_evaluationRecords.map((item) => item.toMap()).toList());
    try {
      await _channel
          .invokeMethod<String>('saveEvaluationResults', {'json': json});
      if (mounted) setState(() => _evaluationMessage = 'Result saved locally.');
    } catch (error) {
      if (mounted) {
        setState(() => _evaluationMessage = 'Could not save result: $error');
      }
    }
  }

  Future<void> _exportEvaluationResults() async {
    if (_evaluationRecords.isEmpty) return;
    final json =
        jsonEncode(_evaluationRecords.map((item) => item.toMap()).toList());
    try {
      final uri = await _channel
          .invokeMethod<String>('exportEvaluationResults', {'json': json});
      if (mounted) {
        setState(() => _evaluationMessage = 'Exported evaluation JSON: $uri');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _evaluationMessage = 'Export cancelled or failed.');
      }
    }
  }

  void _updateGuidedFeedback(String state, String label, double confidence) {
    if (state != 'recognizing' || label == 'Unknown') {
      _consistentTargetPredictions = 0;
      if (state == 'no_hands') {
        _guidedFeedback = 'No hands detected.';
      } else if (state == 'collecting') {
        _guidedFeedback = 'Collecting frames...';
      } else if (state == 'recognizing') {
        _guidedFeedback = 'Unknown or not confident.';
      }
      return;
    }
    if (label == _targetSign && confidence >= 0.65) {
      _consistentTargetPredictions++;
      _guidedFeedback = _consistentTargetPredictions >= 3
          ? 'Target recognized provisionally.'
          : 'Hold steady... $_consistentTargetPredictions/3 consistent predictions.';
    } else {
      _consistentTargetPredictions = 0;
      _guidedFeedback =
          'Different sign detected. Target: ${_targetSign ?? 'not selected'}.';
    }
  }

  Future<void> _resetPractice() async {
    _evaluationTimer?.cancel();
    _evaluationTimer = null;
    _evaluationStartedAt = null;
    _evaluationSamples.clear();
    _consistentTargetPredictions = 0;
    setState(() {
      _guidedFeedback = 'Collecting frames...';
      _recognitionState = 'collecting';
      _predictionLabel = 'Collecting frames';
      _predictionConfidence = 0;
      _recognitionFrames = 0;
      _lastEvaluationRecord = null;
      _evaluationMessage =
          _evaluationMode ? 'Show the target handshape to begin.' : null;
    });
    try {
      await _channel.invokeMethod<void>('resetRecognition');
    } catch (_) {
      // The camera can continue even if a reset arrives during disposal.
    }
  }

  Future<void> _selectTarget(String? target) async {
    if (target == null || target == _targetSign) return;
    setState(() => _targetSign = target);
    await _resetPractice();
  }

  Future<void> _selectMode(String? mode) async {
    if (mode == null || mode == _recognitionMode) return;
    setState(() {
      _recognitionMode = mode;
      _targetSign = null;
      _availableSigns = const [];
      _evaluationMode = false;
      _evaluationMessage = null;
    });
    await _loadSignLabels(mode);
    try {
      await _channel.invokeMethod<void>('setRecognitionMode', {'mode': mode});
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not load the selected model.');
      }
    }
    await _resetPractice();
  }

  Future<void> _nextSign() async {
    if (_availableSigns.isEmpty) return;
    final current =
        _targetSign == null ? -1 : _availableSigns.indexOf(_targetSign!);
    final next = _availableSigns[(current + 1) % _availableSigns.length];
    setState(() => _targetSign = next);
    await _resetPractice();
  }

  Future<void> _showAlphabetReference() async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1D3555),
        insetPadding: const EdgeInsets.all(12),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.sizeOf(context).height * 0.86,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'FSL Alphabet Reference',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        color: Colors.white,
                        icon: const Icon(Icons.close),
                        tooltip: 'Close reference',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    boundaryMargin: const EdgeInsets.all(32),
                    child: Image.asset(
                      'assets/images/fsl_alphabet_dictionary.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Text(
                          'Reference image is unavailable.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Text(
                    '© Lassal, fingeralphabet.org · Version 3.0 Set02 · CC BY-NC-ND 4.0 · Not for sale',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'Camera permission was denied. Allow camera access in Android settings to use Live Practice.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission is disabled. Enable it in Android settings.';
      default:
        return error.description ?? 'The camera is unavailable.';
    }
  }

  Future<void> _disposeCamera() async {
    ++_initializationToken;
    final controller = _controller;
    _controller = null;
    _hands = const [];
    _recognitionState = 'collecting';
    _predictionLabel = 'Collecting frames';
    _predictionConfidence = 0;
    _recognitionFrames = 0;
    _consistentTargetPredictions = 0;
    _guidedFeedback = 'Select a target sign to begin practice.';
    _evaluationTimer?.cancel();
    _evaluationTimer = null;
    _evaluationStartedAt = null;
    _evaluationSamples.clear();
    try {
      if (controller?.value.isStreamingImages == true) {
        await controller!.stopImageStream();
      }
      await controller?.dispose();
    } finally {
      await _channel.invokeMethod<void>('stopTracking');
      if (mounted) setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing) return;
    await _disposeCamera();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return _inactiveView();
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF1D3555),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    if (_errorMessage != null) return _errorView(_errorMessage!);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _errorView('Camera is not ready.');
    }

    final mirrorLandmarks =
        controller.description.lensDirection == CameraLensDirection.front;
    return Scaffold(
      backgroundColor: const Color(0xFF1D3555),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Live Hand Tracking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showAlphabetReference,
                    color: Colors.white,
                    tooltip: 'Open FSL alphabet reference',
                    icon: const Icon(Icons.menu_book_outlined),
                  ),
                  IconButton(
                    onPressed: _switchCamera,
                    color: Colors.white,
                    tooltip: 'Switch camera',
                    icon: const Icon(Icons.cameraswitch_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: _TargetSignSelector(
                signs: _availableSigns,
                selected: _targetSign,
                mode: _recognitionMode,
                onModeChanged: _selectMode,
                onChanged: _selectTarget,
              ),
            ),
            if (_recognitionMode == 'alphabet')
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Alphabet evaluation mode',
                          style: TextStyle(color: Colors.white70)),
                    ),
                    Switch(
                      value: _evaluationMode,
                      onChanged: _toggleEvaluation,
                      activeThumbColor: Colors.lightGreenAccent,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(controller),
                          CustomPaint(
                            painter: HandLandmarkPainter(
                              hands: _hands,
                              mirrorX: mirrorLandmarks,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _StatusPill(
                          text: _isTracking
                              ? '${_hands.length} hand${_hands.length == 1 ? '' : 's'} detected'
                              : 'Tracking paused',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: _RecognitionPanel(
                state: _recognitionState,
                label: _predictionLabel,
                confidence: _predictionConfidence,
                frames: _recognitionFrames,
                requiredFrames: _recognitionMode == 'alphabet' ? 1 : 75,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: _GuidedFeedback(
                text: _guidedFeedback,
                isSuccess: _consistentTargetPredictions >= 3,
              ),
            ),
            if (_evaluationMode && _lastEvaluationRecord != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: _EvaluationResultPanel(record: _lastEvaluationRecord!),
              ),
            if (_evaluationMode && _evaluationMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_evaluationMessage!,
                      style: const TextStyle(color: Colors.white70)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: _evaluationMode
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PracticeButton(
                            icon: Icons.refresh,
                            label: 'Retry',
                            onPressed: _resetPractice),
                        _PracticeButton(
                            icon: Icons.save,
                            label: 'Save result',
                            onPressed: _lastEvaluationRecord == null
                                ? null
                                : _saveEvaluationResult),
                        _PracticeButton(
                            icon: Icons.file_download,
                            label: 'Export JSON',
                            onPressed: _evaluationRecords.isEmpty
                                ? null
                                : _exportEvaluationResults),
                        _PracticeButton(
                            icon: Icons.arrow_forward,
                            label: 'Next letter',
                            onPressed: _nextSign),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _PracticeButton(
                              icon: Icons.refresh,
                              label: 'Retry',
                              onPressed: _resetPractice),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PracticeButton(
                              icon: Icons.arrow_forward,
                              label: _recognitionMode == 'alphabet'
                                  ? 'Next letter'
                                  : 'Next sign',
                              onPressed: _nextSign),
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: FilledButton.icon(
                onPressed: () async {
                  setState(() => _isTracking = !_isTracking);
                  await _channel.invokeMethod<void>(
                      _isTracking ? 'startTracking' : 'stopTracking');
                  if (!_isTracking && mounted) {
                    setState(() {
                      _recognitionState = 'collecting';
                      _predictionLabel = 'Tracking paused';
                      _predictionConfidence = 0;
                      _recognitionFrames = 0;
                    });
                  }
                },
                icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
                label: Text(_isTracking ? 'Stop tracking' : 'Start tracking'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inactiveView() {
    return const Scaffold(
      backgroundColor: Color(0xFF1D3555),
      body: Center(
        child: Text(
          'Open Live Practice to start the camera.',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }

  Widget _errorView(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D3555),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white70, size: 56),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _initializeCamera,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvaluationSample {
  final String label;
  final double confidence;

  const _EvaluationSample(this.label, this.confidence);
}

class AlphabetEvaluationRecord {
  final String targetLetter;
  final String? predictedLetter;
  final double averageConfidence;
  final int predictionCount;
  final String result;
  final DateTime timestamp;

  const AlphabetEvaluationRecord({
    required this.targetLetter,
    required this.predictedLetter,
    required this.averageConfidence,
    required this.predictionCount,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'targetLetter': targetLetter,
        'predictedLetter': predictedLetter,
        'averageConfidence': averageConfidence,
        'predictionCount': predictionCount,
        'result': result,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory AlphabetEvaluationRecord.fromMap(Map<String, dynamic> map) {
    return AlphabetEvaluationRecord(
      targetLetter: map['targetLetter']?.toString() ?? '',
      predictedLetter: map['predictedLetter']?.toString(),
      averageConfidence: (map['averageConfidence'] as num?)?.toDouble() ?? 0,
      predictionCount: (map['predictionCount'] as num?)?.toInt() ?? 0,
      result: map['result']?.toString() ?? 'untested',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class DetectedHand {
  final String handedness;
  final List<Offset> landmarks;

  const DetectedHand({required this.handedness, required this.landmarks});

  factory DetectedHand.fromMap(Map<String, dynamic> map) {
    final raw = map['landmarks'] as List<dynamic>? ?? const [];
    return DetectedHand(
      handedness: map['handedness']?.toString() ?? 'unknown',
      landmarks: raw.map((landmark) {
        final point = Map<String, dynamic>.from(landmark as Map);
        return Offset(
          (point['x'] as num?)?.toDouble() ?? 0,
          (point['y'] as num?)?.toDouble() ?? 0,
        );
      }).toList(),
    );
  }
}

class HandLandmarkPainter extends CustomPainter {
  final List<DetectedHand> hands;

  /// Mirrors only the displayed coordinates when the platform preview is
  /// mirrored. MediaPipe's normalized coordinates remain unchanged.
  final bool mirrorX;

  const HandLandmarkPainter({required this.hands, this.mirrorX = false});

  static const connections = <List<int>>[
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.lightGreenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final hand in hands) {
      final points = hand.landmarks.map((point) {
        final x = mirrorX ? 1 - point.dx : point.dx;
        return Offset(x * size.width, point.dy * size.height);
      }).toList();
      for (final connection in connections) {
        if (connection[0] < points.length && connection[1] < points.length) {
          canvas.drawLine(
              points[connection[0]], points[connection[1]], linePaint);
        }
      }
      for (final point in points) {
        canvas.drawCircle(point, 5, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HandLandmarkPainter oldDelegate) =>
      oldDelegate.hands != hands || oldDelegate.mirrorX != mirrorX;
}

class _StatusPill extends StatelessWidget {
  final String text;

  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _TargetSignSelector extends StatelessWidget {
  final List<String> signs;
  final String? selected;
  final String mode;
  final ValueChanged<String?> onModeChanged;
  final ValueChanged<String?> onChanged;

  const _TargetSignSelector({
    required this.signs,
    required this.selected,
    required this.mode,
    required this.onModeChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Mode', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: mode,
                    dropdownColor: const Color(0xFF1D3555),
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                    items: const [
                      DropdownMenuItem(
                          value: 'vocabulary', child: Text('Vocabulary')),
                      DropdownMenuItem(
                          value: 'alphabet', child: Text('Alphabet (static)')),
                    ],
                    onChanged: onModeChanged,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Target', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: signs.contains(selected) ? selected : null,
                      isExpanded: true,
                      hint: const Text('Loading signs...',
                          style: TextStyle(color: Colors.white)),
                      dropdownColor: const Color(0xFF1D3555),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                      items: signs
                          .map((sign) => DropdownMenuItem<String>(
                                value: sign,
                                child: Text(sign),
                              ))
                          .toList(),
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No validated reference media available; practice feedback only.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidedFeedback extends StatelessWidget {
  final String text;
  final bool isSuccess;

  const _GuidedFeedback({required this.text, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: isSuccess ? Colors.lightGreenAccent : Colors.white70,
          fontWeight: isSuccess ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _PracticeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _PracticeButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
      ),
    );
  }
}

class _EvaluationResultPanel extends StatelessWidget {
  final AlphabetEvaluationRecord record;

  const _EvaluationResultPanel({required this.record});

  @override
  Widget build(BuildContext context) {
    final predicted = record.predictedLetter ?? 'Untested';
    final color = record.result == 'match'
        ? Colors.lightGreenAccent
        : record.result == 'mismatch'
            ? Colors.orangeAccent
            : Colors.white70;
    return Text(
      'Result: ${record.targetLetter} → $predicted · '
      '${(record.averageConfidence * 100).toStringAsFixed(1)}% · '
      '${record.predictionCount} predictions · ${record.result}',
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _RecognitionPanel extends StatelessWidget {
  final String state;
  final String label;
  final double confidence;
  final int frames;
  final int requiredFrames;

  const _RecognitionPanel({
    required this.state,
    required this.label,
    required this.confidence,
    required this.frames,
    required this.requiredFrames,
  });

  @override
  Widget build(BuildContext context) {
    final isRecognizing = state == 'recognizing' && label != 'Unknown';
    final title = switch (state) {
      'no_hands' => 'No hands detected',
      'recognizing' when isRecognizing => label,
      'recognizing' => 'Unknown sign',
      _ => '$label ($frames/$requiredFrames)',
    };
    final hasPrediction = state == 'recognizing';
    final subtitle = hasPrediction
        ? '${(confidence * 100).toStringAsFixed(1)}% confidence'
        : state == 'no_hands'
            ? 'Show one or two hands to begin'
            : 'Recognition starts after $requiredFrames valid frame${requiredFrames == 1 ? '' : 's'}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isRecognizing ? Icons.auto_awesome : Icons.hourglass_top,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
