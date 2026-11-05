# Flow: assessments and marks

Files: [assessments_screen.dart](../../lib/features/marks/screens/assessments_screen.dart) ·
[marks_entry_screen.dart](../../lib/features/marks/screens/marks_entry_screen.dart) ·
[marks_api.dart](../../lib/features/marks/data/marks_api.dart)

## Assessments

The teacher decides what exists and what it's worth. The green panel shows how much of the course total is given out, and the backend refuses anything that would go over.

Adding one takes two taps: a suggestion chip fills the name (`Quiz` becomes `Quiz 2` if `Quiz 1` exists), and the marks box starts with what's left. **Lab work** puts an assessment in the Lab column of the result sheet.

`AssessmentsScreen` serves two jobs through its `action` setting. From **Marks**, a row opens marks entry. From **Question papers**, the same row opens the paper. The ⋮ menu always offers the other one.

## Trace: entering a mark

```
Tap an assessment
  ▼ MarksEntryScreen → GET /assessments/<id>/marks?sectionId=<id>
  ▼ opens at the first student with no mark, so stopping halfway is safe
Teacher taps 8 . 5 on the pad        _press builds the text "8.5"
  ▼ "Save and next" → _saveAndNext
      _record: puts the mark in _waiting and starts _flush
      _advance: the next student appears straight away
  ▼ in the background: _sendAll
      PUT /assessments/<id>/marks { marks: [...] }
      success → those marks leave _waiting
      failure → they stay, and a red line offers "Try again"
```

## Why marks save in the background

Waiting for the server after each student would add about a second per student, 60 times. So the mark goes into `_waiting`, a list of marks not yet confirmed saved, and the teacher moves on.

Three rules keep that safe:

| Rule | How |
|---|---|
| Only one save runs at a time | `_flush` joins the save already running instead of starting another |
| Nothing is lost on failure | A mark leaves `_waiting` only after the server confirms it, so the next save sends it again |
| Leaving waits | `_leave` waits for the save to finish. If marks are still unsaved, it asks before closing |

## Three kinds of "no number"

| Teacher does | Sent | Means |
|---|---|---|
| Leaves the pad empty and taps next | Nothing | Student stays as they were |
| Taps **Absent** | `marks: null` | No mark, and clears any mark entered before |
| Enters 0 | `marks: 0` | A real zero: they sat it and scored nothing |

The database can't tell "absent" from "not entered yet", so both show as `–`. A student with no marks at all prints as Absent on the result sheet.

## Try it

1. Open **Marks**, add `Quiz` worth 10, tap it.
2. Enter `8.5`, then **Save and next**. The strip shows the mark at once.
3. Type `11`: the panel turns coral, says **Too high**, and the save button turns off.
