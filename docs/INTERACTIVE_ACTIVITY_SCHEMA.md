# Interactive Lesson Activity Schema Proposal

This is a local proposal only. It has not been migrated, seeded, deployed, or written to Firestore.

## Backward compatibility

Existing lesson documents remain valid. If `activities` is absent or empty, the app derives read-only sign-identification activities from the lesson's existing `signIds` and sign media fields. Existing lesson quiz and grammar collections remain unchanged.

## Optional lesson field

Add an `activities` array to a future `lessons/{lessonId}` document:

```json
{
  "activities": [
    {
      "id": "greetings_identify_01",
      "type": "identification",
      "instruction": "Watch the reviewed reference and identify the sign.",
      "prompt": "What does this sign mean?",
      "mediaUrl": "<reviewed-media-url>",
      "mediaType": "gif",
      "options": ["Hello", "Goodbye", "Thank you"],
      "correctAnswer": "Hello"
    },
    {
      "id": "greetings_match_01",
      "type": "matching",
      "instruction": "Match each sign concept to its context.",
      "pairs": [
        {"left": "Hello", "right": "greeting"},
        {"left": "Doctor", "right": "health"}
      ]
    },
    {
      "id": "greetings_order_01",
      "type": "ordering",
      "instruction": "Arrange the concepts in the guided order.",
      "items": ["Need", "Help"],
      "correctOrder": ["Need", "Help"]
    },
    {
      "id": "greetings_context_01",
      "type": "conversation",
      "instruction": "Choose the most appropriate response.",
      "prompt": "Someone greets you. What should you sign?",
      "options": ["Hello", "Hospital", "Bus"],
      "correctAnswer": "Hello"
    },
    {
      "id": "greetings_mixed_01",
      "type": "mixed",
      "activities": []
    }
  ]
}
```

## Validation rules

- Unsupported or malformed activities are ignored safely during parsing.
- Identification and conversation activities require at least two options and a matching correct answer.
- Matching activities require non-empty left/right pairs.
- Ordering activities require the same unique values in `items` and `correctOrder`.
- Media is optional; missing or inaccessible media shows a safe fallback state.
- Actual FSL content must be reviewed, licensed, and approved before any production migration.

## Progress storage proposal

Activity attempts should eventually be stored under:

```text
users/{userId}/lessonProgress/{lessonId}
  bestActivityScore
  activityAttempts/{activityId}
    attempts
    bestScore
    completed
    updatedAt
```

This requires a reviewed security-rule/backend design. The current implementation keeps new activity-runner scores local to the lesson session and leaves existing lesson completion/XP transactions unchanged.
