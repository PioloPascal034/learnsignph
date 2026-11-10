# FSL Alphabet Real-World Evaluation

Device: `192.168.8.35:39595`  
Mode: Alphabet (static)  
Model: `alphabet_mlp.tflite` (`[1,63] -> [1,24]`)

The phone launched Alphabet mode and displayed target `A`. No hand was presented during the recorded observation, so the application correctly reported **No hands detected**. No prediction or confidence was recorded, and no letter is marked as working.

All 24 static letters remain untested in the physical-camera evaluation. J and Z are excluded because the current model is static and cannot evaluate motion signs.

The structured record is in [`FSL_ALPHABET_EVALUATION_REPORT.json`](./FSL_ALPHABET_EVALUATION_REPORT.json). Use the manual protocol there to fill one row per physically demonstrated letter. Offline model metrics must not be substituted for this live-camera evaluation.
