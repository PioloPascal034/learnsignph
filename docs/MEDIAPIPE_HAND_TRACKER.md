# Android Hand Tracking Foundation

This phase uses Flutter's official `camera` plugin for the preview and Android YUV420 image stream, and Google's native MediaPipe Tasks Vision Hand Landmarker through a Flutter `MethodChannel`.

The Android build downloads the official `hand_landmarker.task` model at build time from Google's public MediaPipe model endpoint:
`https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task`
The model is used only for generic hand landmark detection; it is not an FSL classifier and does not make sign-meaning claims. Review the model's distribution terms and Google's MediaPipe licensing terms before distributing the app. The MediaPipe Tasks Android library is consumed as `com.google.mediapipe:tasks-vision:1.2.2`.

The native bridge converts the camera's YUV420 planes to a JPEG bitmap on a single background executor, applies the sensor rotation, and submits frames in LIVE_STREAM mode with `numHands = 2`. Results are returned asynchronously with normalized coordinates and handedness. Flutter renders the 21-point hand topology using `CustomPainter`. Front-camera mirroring is applied to the preview and overlay while status controls remain readable.

The implementation intentionally excludes gesture classification, FSL recognition, correctness scoring, XP, and Firebase writes.
