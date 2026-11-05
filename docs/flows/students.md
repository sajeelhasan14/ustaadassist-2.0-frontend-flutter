# Flow: adding students

Files: [students_screen.dart](../../lib/features/students/screens/students_screen.dart) ·
[capture_list_screen.dart](../../lib/features/students/screens/capture_list_screen.dart) ·
[review_list_screen.dart](../../lib/features/students/screens/review_list_screen.dart) ·
[students_api.dart](../../lib/features/students/data/students_api.dart)

Nobody types a class list. The teacher photographs it or picks a file, AI reads it, and the teacher checks the result.

## Trace: importing a class list

```
Students: "Import list"
  ▼ CaptureListScreen
Teacher takes photos (image_picker) or picks a PDF, Excel or CSV (file_picker)
  ▼ _add checks the limits first: 10 files, 20 MB together
"Read the list" → StudentsApi.extract
  ▼ POST /students/extract (multipart, up to 200 seconds, AI reads it, nothing saved)
  ▼ ReviewListScreen, every row with its status
Teacher fixes or removes the flagged rows
  ▼ "Confirm N students" → StudentsApi.import
      POST /sections/<id>/import (all rows saved, or none)
  ▼ both screens close, the list reloads
```

## What each row status does

| Status | Meaning | On screen |
|---|---|---|
| `new`, `existing` | Ready | Plain row |
| `missing_data`, `duplicate_in_file`, `seat_number_taken` | Needs the teacher | Red row with editable fields; editing it clears the flag |
| `not_in_file` | AI may have misread it | Red row, plus an "It's correct" button |
| `already_enrolled`, `in_other_section` | Nothing to do | Grey row marked Skipped, not sent |

**Confirm stays off while any row needs the teacher**, because a wrong seat number follows that student all semester. The backend still checks everything again, and if it refuses, its message appears above the button and nothing is saved.

## Adding or fixing one student

`_StudentDialog` handles both. No student passed in means add (`POST /sections/<id>/students`); a student means edit (`PATCH /students/<id>`). A fix shows in every course that student is in, because there is only one record of them.

The remove button only takes them out of this section (`DELETE /sections/<id>/students/<id>`).

## Try it

1. Open a course, tap **Students**, then **Import list**.
2. Pick the `Sec A 2026.pdf` list.
3. Rows 21 and 22 share a seat number, so both come back red. Fix one and watch **Confirm** turn on.
