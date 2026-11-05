# Flow: question papers

Files: [paper_screen.dart](../../lib/features/papers/screens/paper_screen.dart) ·
[generate_paper_screen.dart](../../lib/features/papers/screens/generate_paper_screen.dart) ·
[question_edit_screen.dart](../../lib/features/papers/screens/question_edit_screen.dart) ·
[papers_api.dart](../../lib/features/papers/data/papers_api.dart)

The teacher says what paper they want, AI writes a draft of questions (no answers), and the teacher checks it. **Only approved questions reach the printed paper.**

## Trace: generating a paper

```
Question papers → tap an assessment
  ▼ PaperScreen → GET /assessments/<id>/questions   (empty: green panel, "Generate paper")
  ▼ GeneratePaperScreen
Teacher picks an idea chip or types, and may tick topics with marks
  ▼ "Write the paper" → PapersApi.generate
      POST /assessments/<id>/questions/generate     up to 200 seconds
  ▼ 201 → closes with a GenerateResult
PaperScreen reloads and shows the drafts
  ▼ if the marks missed the target, a message says so; the app never changes AI's work
Teacher edits, rewrites or deletes, then "Approve all"
  ▼ PATCH /assessments/<id>/questions { status: "approved" }
"PDF" → asks the time allowed → GET .../questions?format=pdf&time=3 hours → saveFile
```

## Why topics take numbers, not words

Tests showed that wording like "mostly Testing" made the AI skip the other topics completely, while plain numbers were followed. So each ticked topic has its own marks box. With no topics ticked, the backend uses what has been taught so far.

## When AI fails

On the free key about 2 calls in 5 failed. A failure doesn't lose anything: the error appears, the instructions stay, and the button becomes **Try again**.

## What each question can do

| Action | Where | Request |
|---|---|---|
| Approve, or back to draft | Button on the card | `PATCH /questions/<id>` |
| Edit | ⋮ menu → `QuestionEditScreen` | `PATCH /questions/<id>` |
| Rewrite with AI | ⋮ menu | `POST /questions/<id>/regenerate` |
| Move up or down | ⋮ menu | `PUT /assessments/<id>/questions`, the whole order |
| Delete | ⋮ menu, asks first | `DELETE /questions/<id>` |

The paper's own ⋮ menu adds a section, adds a question, throws away drafts, or clears everything. A section can have a title, instructions and "attempt any N".

The number in the green panel is approved marks out of the assessment's marks. It comes from the backend, because with "attempt any 4" only the best 4 questions count.

## Try it

1. Open **Question papers**, tap an assessment, then **Generate paper**.
2. Tap **Mixed paper** and **Write the paper**. Wait for it; this can take two minutes.
3. Open one question's ⋮ menu and **Rewrite with AI**.
4. **Approve all**, then **PDF**.
