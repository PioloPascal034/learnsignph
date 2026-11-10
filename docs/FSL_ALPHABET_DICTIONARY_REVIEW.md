# FSL Alphabet Dictionary Review

## Local reference

The supplied image is an unmodified Project FingerAlphabet poster labelled:

- `Version 3.0 Set02`
- `© Lassal, www.fingeralphabet.org`
- `CC BY-NC-ND 4.0`
- `NOT FOR SALE`

The source site identifies the chart as a Filipino Sign Language alphabet resource: <https://fingeralphabet.org/almost-done/fsl-charts-almost-done/>.

The image is now copied unchanged to [`assets/images/fsl_alphabet_dictionary.png`](../assets/images/fsl_alphabet_dictionary.png) and displayed with attribution in the app. CC BY-NC-ND permits noncommercial redistribution with attribution, but prohibits distributing adapted versions. If LearnSign PH becomes commercial or the image is cropped/modified, obtain separate permission first.

## Visual inspection

The poster contains A–Z. J and Z include motion arrows, so they are not static single-frame classes. The 24 remaining letters are presented as static handshapes.

The Kaggle dataset used for the alphabet model contains folders A–Z with 450 images per class. The static model intentionally excludes J and Z. A representative visual comparison against the extracted Kaggle images found no basis for silently changing folder labels, but it also cannot establish that every illustrated handshape is community-authoritative or signer-equivalent. Differences in hand orientation, perspective, and left/right presentation are visible and are treated as variation, not relabeling evidence.

The dataset has no participant metadata. Its labels were accepted from the source folder structure, not independently revalidated by LearnSign PH or a Deaf-community reviewer. The dictionary is therefore a learning reference with provenance, not a correctness oracle for model predictions.

## Dynamic-letter requirements

- J: collect a short temporal sequence showing the required curved movement, not a single static frame.
- Z: collect a short temporal sequence showing the required tracing movement, not a single static frame.
- Both require timestamped 21-landmark sequences, motion features such as velocity/trajectory, and signer-independent evaluation before recognition is enabled.
- The current alphabet MLP must not be used to score J or Z.
