"""Prepare one development FSL-105 clip per label and a stable sign manifest.

The source archive is not uploaded or published by this script. Each selected
clip remains a local development asset and is marked source_label_review_pending
until the actual sign/video is visually reviewed by an authorized reviewer.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
from pathlib import Path


DATASET_URL = "https://data.mendeley.com/datasets/48y2y99mb9/2"
LICENSE_URL = "https://creativecommons.org/licenses/by/4.0/"
CREATOR = "Isaiah Jassen Tupal / De La Salle University"


def slug(value: str) -> str:
    value = value.strip().lower().replace("’", "'")
    value = re.sub(r"[^a-z0-9]+", "_", value).strip("_")
    return value or "unknown"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--labels", type=Path, required=True)
    parser.add_argument("--train", type=Path, required=True)
    parser.add_argument("--clips-root", type=Path, required=True)
    parser.add_argument("--assets-root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--content", type=Path, required=True)
    parser.add_argument("--curriculum", type=Path, required=True)
    args = parser.parse_args()

    labels = list(csv.DictReader(args.labels.open(encoding="utf-8-sig", newline="")))
    train = list(csv.DictReader(args.train.open(encoding="utf-8-sig", newline="")))
    first_clip_by_id: dict[str, str] = {}
    for row in train:
        first_clip_by_id.setdefault(row["id_label"], row["vid_path"])

    args.assets_root.mkdir(parents=True, exist_ok=True)
    manifest_assets = []
    signs = []
    for row in labels:
        label = row["label"].strip()
        category = row["category"].strip().lower()
        sign_id = f"fsl105_{slug(label)}"
        relative_source = first_clip_by_id.get(row["id"])
        if not relative_source:
            continue
        source_file = args.clips_root.joinpath(*re.split(r"[\\/]", relative_source))
        asset_name = f"{sign_id}.MOV"
        target_file = args.assets_root / asset_name
        if source_file.exists():
            shutil.copy2(source_file, target_file)

        asset_path = f"assets/media/fsl105/{asset_name}"
        media_id = f"{sign_id}_video_01"
        media = {
            "mediaId": media_id,
            "signId": sign_id,
            "mediaType": "video",
            "assetPath": asset_path,
            "sourceArchivePath": relative_source.replace("\\", "/"),
            "sourceUrl": DATASET_URL,
            "creator": CREATOR,
            "license": "CC BY 4.0",
            "licenseUrl": LICENSE_URL,
            "attribution": f"{CREATOR}; FSL-105 dataset, Mendeley Data v2",
            "validationStatus": "source_label_review_pending",
        }
        manifest_assets.append(media)
        signs.append({
            "id": sign_id,
            "word": label,
            "videoUrl": f"asset:{asset_path}",
            "imageUrl": "",
            "gifUrl": "",
            "category": category,
            "difficulty": "beginner",
            "sourceUrl": DATASET_URL,
            "license": "CC BY 4.0",
            "attribution": media["attribution"],
            "validationStatus": "source_label_review_pending",
            "supportedRecognitionMode": "words" if category not in {"number"} else "numbers_pending_model",
            "mediaRefs": [media],
        })

    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps({
        "dataset": {
            "name": "FSL-105",
            "version": 2,
            "url": DATASET_URL,
            "doi": "10.17632/48y2y99mb9.2",
            "license": "CC BY 4.0",
            "licenseUrl": LICENSE_URL,
            "creator": CREATOR,
        },
        "status": "development_source_label_review_pending",
        "assets": manifest_assets,
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    args.content.parent.mkdir(parents=True, exist_ok=True)
    args.content.write_text(json.dumps({
        "metadata": {
            "contentStatus": "development_source_label_review_pending",
            "source": DATASET_URL,
            "license": "CC BY 4.0",
            "creator": CREATOR,
            "mediaManifest": str(args.manifest).replace("\\", "/"),
        },
        "signs": signs,
        "lessons": [],
        "grammarExercises": [],
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    by_category: dict[str, list[dict[str, object]]] = {}
    for sign in signs:
        by_category.setdefault(str(sign["category"]), []).append(sign)

    def lesson(
        lesson_id: str,
        title: str,
        category: str,
        sign_groups: tuple[str, ...],
        description: str,
        image_url: str = "",
        status: str = "source_label_review_pending",
    ) -> dict[str, object]:
        selected = [
            sign for group in sign_groups for sign in by_category.get(group, [])
        ]
        pairs = [
            {"left": str(sign["word"]), "right": str(sign["id"])}
            for sign in selected[:8]
        ]
        return {
            "id": lesson_id,
            "title": title,
            "category": category,
            "difficulty": "beginner",
            "description": description,
            "imageUrl": image_url,
            "learningObjectives": [
                "Recognize the provided label and its development media reference.",
                "Practice one sign at a time without inferring unsupported grammar.",
                "Record uncertainty for FSL review before publication.",
            ],
            "explanation": "This development lesson uses FSL-105 source labels and clips. The source label and license are recorded, but the sign/video pairing remains pending visual and FSL-community review.",
            "referencedVocabulary": [str(sign["id"]) for sign in selected],
            "signIds": [str(sign["id"]) for sign in selected],
            "activities": [{
                "id": f"{lesson_id}_matching",
                "type": "matching",
                "instruction": "Match each source label to its stable sign record.",
                "prompt": "Match labels to the development records without treating this as a language-authority claim.",
                "pairs": pairs,
            }] if pairs else [{
                "id": f"{lesson_id}_reference_workflow",
                "type": "ordering",
                "instruction": "Order the safe reference workflow.",
                "prompt": "Prepare a static alphabet reference for qualified review.",
                "items": ["Open the licensed reference", "Practice a static letter", "Request FSL review"],
                "correctOrder": ["Open the licensed reference", "Practice a static letter", "Request FSL review"],
            }],
            "quizQuestions": [{
                "prompt": "What should happen before this lesson is published as authoritative FSL instruction?",
                "options": ["Qualified FSL/community review", "Copy an unrelated ASL sign", "Remove the source record"],
                "correctAnswer": "Qualified FSL/community review",
                "feedback": "The dataset license permits reuse with attribution, but it does not by itself prove community validation of each teaching claim.",
            }],
            "sourceReferences": [DATASET_URL, LICENSE_URL],
            "contentValidationStatus": status,
            "mediaStatus": "local_development_asset" if selected else "licensed_local_reference_only",
            "isActive": True,
        }

    curriculum = {
        "metadata": {
            "contentStatus": "development_source_label_review_pending",
            "source": DATASET_URL,
            "license": "CC BY 4.0",
            "creator": CREATOR,
        },
        "signs": signs,
        "lessons": [
            lesson(
                "fsl105_lesson_alphabet",
                "Alphabet and Fingerspelling",
                "alphabet",
                tuple(),
                "Use the existing licensed alphabet reference while keeping J and Z separate from static recognition.",
                "asset:assets/images/fsl_alphabet_dictionary.png",
                "reference_only_media_review_pending",
            ),
            lesson("fsl105_lesson_numbers", "Numbers", "numbers", ("number",), "Practice the ten number labels present in FSL-105."),
            lesson("fsl105_lesson_greetings", "Greetings", "greetings", ("greeting",), "Practice FSL-105 greeting labels one sign at a time."),
            lesson("fsl105_lesson_family", "Family", "family", ("family",), "Practice family labels from the FSL-105 source set."),
            lesson("fsl105_lesson_everyday_words", "Everyday Words", "everyday_words", ("survival", "relationships"), "Practice everyday survival and relationship vocabulary from the source set."),
            lesson("fsl105_lesson_food_drinks", "Food and Drinks", "food_drinks", ("food", "drink"), "Practice food and drink labels from the source set."),
            lesson("fsl105_lesson_colors_time", "Colors and Time", "colors_time", ("color", "calendar", "days"), "Practice color, calendar, and day/time reference labels from the source set."),
        ],
        "grammarExercises": [],
    }
    args.curriculum.parent.mkdir(parents=True, exist_ok=True)
    args.curriculum.write_text(json.dumps(curriculum, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"signs": len(signs), "media": len(manifest_assets)}))


if __name__ == "__main__":
    main()
