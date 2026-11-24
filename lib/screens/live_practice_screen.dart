import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _livePrimaryText = Color(0xFFE7F0F7);
const _liveMutedText = Color(0xFFB8CAD8);

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
  String? _errorMessage;
  final ValueNotifier<List<DetectedHand>> _handsNotifier =
      ValueNotifier(const []);

  String _recognitionMode = 'alphabet';
  String _recognitionState = 'collecting';
  String _predictionLabel = 'Waiting for a sign';
  double _predictionConfidence = 0;
  String _guidedFeedback =
      'Recognition is continuous while the camera is running.';
  DateTime _lastPredictionUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeMessage);
    if (widget.isActive) _initializeCamera();
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
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    try {
      final cameras = await availableCameras();
      if (!mounted || token != _initializationToken) return;
      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'No camera is available on this device.';
        });
        return;
      }

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
      if (mounted && token == _initializationToken) {
        setState(() => _isInitializing = false);
      }
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
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    return front >= 0 ? front : 0;
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _controller == null) return;
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
        'rotation': _frameRotation(_controller!),
      });
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Tracking error: $error');
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  int _frameRotation(CameraController controller) {
    final deviceRotation = switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final sensorOrientation = controller.description.sensorOrientation;
    if (controller.description.lensDirection == CameraLensDirection.front) {
      return (sensorOrientation + deviceRotation) % 360;
    }
    return (sensorOrientation - deviceRotation + 360) % 360;
  }

  Future<void> _handleNativeMessage(MethodCall call) async {
    if (!mounted || !widget.isActive) return;
    if (call.method == 'onLandmarks') {
      final data = Map<String, dynamic>.from(call.arguments as Map);
      final rawHands = data['hands'] as List<dynamic>? ?? const [];
      _handsNotifier.value = rawHands
          .map((hand) =>
              DetectedHand.fromMap(Map<String, dynamic>.from(hand as Map)))
          .toList();
      if (mounted && _errorMessage != null) {
        setState(() => _errorMessage = null);
      }
    } else if (call.method == 'onPrediction') {
      final data = Map<String, dynamic>.from(call.arguments as Map);
      final state = data['state']?.toString() ?? 'collecting';
      final label = data['label']?.toString() ?? 'Unknown';
      final confidence = (data['confidence'] as num?)?.toDouble() ?? 0;
      if (state != _recognitionState || label != _predictionLabel) {
        debugPrint(
            '[Recognition] received state=$state label=$label confidence=$confidence');
      }
      _processContinuousPrediction(state, label, confidence);
    } else if (call.method == 'onError') {
      setState(() => _errorMessage = call.arguments?.toString());
    }
  }

  void _processContinuousPrediction(
    String state,
    String label,
    double confidence,
  ) {
    final now = DateTime.now();
    final isConfident = state == 'recognizing' && label != 'Unknown';

    if (state == 'no_hands') {
      if (_recognitionState == state &&
          now.difference(_lastPredictionUiUpdate).inMilliseconds < 250) {
        return;
      }
      _lastPredictionUiUpdate = now;
      setState(() {
        _recognitionState = state;
        _predictionLabel = 'No hands detected';
        _predictionConfidence = 0;
        _guidedFeedback = 'Show one hand in the camera to begin.';
      });
      return;
    }

    // Native inference already averages three predictions. Only throttle
    // unchanged output; a new letter must be displayed immediately.
    if (state == _recognitionState &&
        label == _predictionLabel &&
        now.difference(_lastPredictionUiUpdate).inMilliseconds < 150) {
      return;
    }
    _lastPredictionUiUpdate = now;
    setState(() {
      _recognitionState = state;
      _predictionLabel = label;
      _predictionConfidence = confidence;
      _guidedFeedback = isConfident
          ? 'Live prediction updated from the latest stable frames.'
          : 'The model is not confident yet.';
    });
  }

  Future<void> _resetScan() async {
    _recognitionState = 'collecting';
    _predictionLabel = 'Waiting for a sign';
    _predictionConfidence = 0;
    _guidedFeedback = _recognitionMode == 'numbers'
        ? 'Number recognition is coming soon.'
        : 'Recognition is continuous while the camera is running.';
    if (mounted) setState(() {});
    try {
      await _channel.invokeMethod<void>('resetRecognition');
    } catch (_) {
      // The camera can remain active when the native recognizer is resetting.
    }
  }

  Future<void> _selectMode(String? mode) async {
    if (mode == null || mode == _recognitionMode) return;
    setState(() {
      _recognitionMode = mode;
    });
    if (mode == 'numbers') {
      await _resetScan();
      if (mounted) setState(() {});
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        'setRecognitionMode',
        {'mode': mode == 'alphabet' ? 'alphabet' : 'words'},
      );
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not load the selected model.');
      }
    }
  }

  Future<void> _showAlphabetReference() async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1D3555),
        insetPadding: const EdgeInsets.all(12),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.86,
            child: Column(
              children: [
                ListTile(
                  title: const Text('FSL Alphabet Reference',
                      style: TextStyle(color: _livePrimaryText)),
                  trailing: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.asset(
                      'assets/images/fsl_alphabet_dictionary.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '© Lassal, fingeralphabet.org · CC BY-NC-ND 4.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _liveMutedText, fontSize: 11),
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
        return 'Camera permission was denied. Allow camera access in Android settings.';
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
    _handsNotifier.value = const [];
    try {
      if (controller?.value.isStreamingImages == true) {
        await controller!.stopImageStream();
      }
      await controller?.dispose();
    } finally {
      try {
        await _channel.invokeMethod<void>('stopTracking');
      } on PlatformException {
        // Native tracking may already be torn down.
      }
      if (mounted) setState(() => _isInitializing = false);
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
    _handsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return _inactiveView();
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF1D3555),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
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
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Live Practice',
                        style: TextStyle(
                            color: _livePrimaryText,
                            fontSize: 27,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (_recognitionMode == 'alphabet')
                    IconButton(
                      onPressed: _showAlphabetReference,
                      color: Colors.white,
                      tooltip: 'Open alphabet reference',
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
              child: _buildModeSelector(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cameraAspect = controller.value.aspectRatio > 0
                      ? controller.value.aspectRatio
                      : 4 / 3;
                  final naturalHeight = constraints.maxWidth / cameraAspect;
                  final height = naturalHeight
                      .clamp(180.0, MediaQuery.sizeOf(context).height * 0.42)
                      .toDouble();
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: cameraAspect,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CameraPreview(controller),
                                    ValueListenableBuilder<List<DetectedHand>>(
                                      valueListenable: _handsNotifier,
                                      builder: (context, hands, _) {
                                        return CustomPaint(
                                          painter: HandLandmarkPainter(
                                            hands: hands,
                                            mirrorX: mirrorLandmarks,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: ValueListenableBuilder<List<DetectedHand>>(
                              valueListenable: _handsNotifier,
                              builder: (context, hands, _) => _StatusPill(
                                text: hands.isEmpty
                                    ? 'No hands detected'
                                    : '${hands.length} hand${hands.length == 1 ? '' : 's'} detected',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildReferenceCard(),
                    const SizedBox(height: 8),
                    _buildRecognitionCard(),
                    const SizedBox(height: 8),
                    Text(_guidedFeedback,
                        style: const TextStyle(color: _liveMutedText)),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    final numbersComingSoon = _recognitionMode == 'numbers';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Text('Mode', style: TextStyle(color: _liveMutedText)),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _recognitionMode,
                dropdownColor: const Color(0xFF1D3555),
                iconEnabledColor: Colors.white,
                style: const TextStyle(
                    color: _livePrimaryText, fontWeight: FontWeight.w700),
                items: const [
                  DropdownMenuItem(value: 'alphabet', child: Text('Alphabet')),
                  DropdownMenuItem(value: 'numbers', child: Text('Numbers')),
                  DropdownMenuItem(value: 'words', child: Text('Words')),
                ],
                onChanged: _selectMode,
              ),
            ),
            const Spacer(),
            Text(
              numbersComingSoon ? 'Coming Soon' : 'Live interpretation',
              style: TextStyle(
                color: numbersComingSoon ? Colors.amberAccent : _liveMutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceCard() {
    final isAlphabet = _recognitionMode == 'alphabet';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          if (isAlphabet)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/fsl_alphabet_dictionary.png',
                width: 58,
                height: 58,
                fit: BoxFit.contain,
              ),
            )
          else
            const Icon(Icons.image_not_supported_outlined,
                color: Colors.white54, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAlphabet
                  ? 'Alphabet reference available. Use it as a learning reference, not as proof of correct FSL execution.'
                  : 'No authorized validated demonstration is available for this mode yet.',
              style: const TextStyle(color: _liveMutedText, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionCard() {
    final hasPrediction =
        _recognitionState == 'recognizing' && _predictionLabel != 'Unknown';
    final noHands = _recognitionState == 'no_hands';
    final title = noHands
        ? 'No hands detected'
        : hasPrediction
            ? 'Live prediction'
            : 'Not Confident';
    final subtitle = noHands
        ? 'Show one hand in the camera.'
        : hasPrediction
            ? 'Predicted $_predictionLabel · ${(_predictionConfidence * 100).toStringAsFixed(1)}% confidence'
            : 'Recognition updates continuously while the camera is running.';
    final color = noHands
        ? _liveMutedText
        : !hasPrediction
            ? _livePrimaryText
            : Colors.lightGreenAccent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(
            noHands ? Icons.pan_tool_outlined : Icons.radar,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    hasPrediction
                        ? _predictionLabel
                        : 'Waiting for a prediction',
                    style: const TextStyle(
                        color: _livePrimaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style:
                        const TextStyle(color: _liveMutedText, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inactiveView() {
    return const Scaffold(
      backgroundColor: Color(0xFF1D3555),
      body: Center(
        child: Text('Open Live Practice to start the camera.',
            style: TextStyle(color: _livePrimaryText, fontSize: 18)),
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
                  style:
                      const TextStyle(color: _livePrimaryText, fontSize: 16)),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _initializeCamera, child: const Text('Try again')),
            ],
          ),
        ),
      ),
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
        child: Text(text, style: const TextStyle(color: _livePrimaryText)),
      ),
    );
  }
}
