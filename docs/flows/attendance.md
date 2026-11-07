# Flow: taking attendance

Files: [take_attendance_screen.dart](../../lib/features/attendance/screens/take_attendance_screen.dart) ·
[classes_screen.dart](../../lib/features/attendance/screens/classes_screen.dart) ·
[attendance_report_screen.dart](../../lib/features/attendance/screens/attendance_report_screen.dart) ·
[extra_class_dialog.dart](../../lib/features/attendance/widgets/extra_class_dialog.dart) ·
[attendance_api.dart](../../lib/features/attendance/data/attendance_api.dart)

The rule behind the screen: **everyone starts present, so the teacher only taps the few who aren't.** A class of 60 with 3 absent is 3 taps and one button.

## Trace: "Take attendance" on Home

```
Home: "Take attendance" button (or a row under TODAY)
  ▼ _attendanceFor(item) builds a ClassRef { sectionId, date, startTime, title }
TakeAttendanceScreen
  ▼ _load → AttendanceApi.open(ref)
      POST /sections/<id>/sessions        a planned class has no id yet, so this finds or creates it
      GET  /sessions/<id>/attendance      the roster, everyone suggested present   ┐ together
      GET  /sections/<id>/sessions        the plan, to pre-fill the topic          ┘
  ▼ topic shown: what was saved, else what the plan has for this class, else the next topic
Teacher taps the absent students           only changes _absent, nothing is sent yet
  ▼ "Submit attendance" → AttendanceApi.save
      PUT /sessions/<id>/attendance { absent: [...], topicIds: [...] }
  ▼ 200 → screen closes → Home reloads and shows the class as Done
```

Why a `ClassRef` and not a class id? Planned classes aren't stored, so they have no id until something happens to them. A section, date and time identify a class before it exists.

Who came and what was taught are separate records. They share one screen and one save only to save the teacher a step ([planner.md](../../../backend/docs/flows/planner.md)).

## The class list

`ClassesScreen` splits the calendar into three blocks:

| Block | Holds | Tapping a row |
|---|---|---|
| TO MARK | Planned classes from today or earlier | Opens attendance |
| UPCOMING | Classes after today | Nothing; the ⋮ menu can cancel it |
| PAST | Held, cancelled and off days | Held classes reopen to fix a mistake |

Cancelling sends `POST /sections/<id>/sessions` with `status: "cancelled"`. Restoring sends `PATCH /sessions/<id>`. The plan moves by itself on the next load.

## The report

`AttendanceReportScreen` reads `GET /sections/<id>/attendance`. The backend works out each percentage and who is short (below 75%). The screen only sorts the short students to the top, lowest first.

## The warning

Two places tell the teacher about shortage, and both use the line from the Me screen.

- **After saving:** `_warnIfShort()` reads the report and shows the students who were absent today and are now below the line. Students who were already short and came today aren't repeated. If the report fails to load nothing is shown, because the attendance is already saved.
- **On Home:** an amber card per section with anyone below the line, from `attendanceAlerts` in `GET /today`. Tapping it opens the report. Pull down on Home to refresh it after changing the line.

Neither counts a student until they have 4 marked classes, because with fewer, a single absence falls below 75%.

## Try it

1. Sign in, open a course with students and a timetable.
2. Tap **Attendance**, then **Take** on today's class.
3. Tap two names, and watch the green panel's count drop.
4. Submit, then open the same class again: your two absentees are still marked and the button says **Update attendance**.
