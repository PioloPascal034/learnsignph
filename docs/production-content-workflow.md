# Production content workflow

The Phase 6A importer is intentionally read-only by default and targets the
local Firestore emulator unless told otherwise.

## Required authorization

Production writes use a short-lived Firebase ID token for the existing content
admin account (`marcronielbisac@gmail.com`). The token must be supplied through
the `FIREBASE_ID_TOKEN` environment variable. The importer does not print or
store the token. No service account, new Firebase project, or Firebase rule
weakening is required.

The Firestore rules continue to enforce:

- signed-in reads for grammar exercises;
- content-admin create/update for lessons, signs, and grammar exercises;
- no deletes;
- user progress isolated under each user's own document.

## Review flow

1. Review and approve the prepared content and its source/media manifest.
2. Preview against the emulator:

   `python tools/import_phase6a_content.py --operation preview`

3. Preview production only after setting a short-lived admin token:

   `python tools/import_phase6a_content.py --target production --operation preview`

4. After explicit approval, use `--operation publish` with
   `FIREBASE_ID_TOKEN` set. Publish refuses records without an approved content
   status, creates missing stable IDs, and updates only changed fields.

The current Phase 6A JSON is draft content, so production publish is expected
to remain blocked until FSL/community review marks the records approved.

The workflow never issues Firestore deletes and never touches user progress
collections.
