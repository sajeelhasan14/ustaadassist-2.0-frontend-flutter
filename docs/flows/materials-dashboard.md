# Flow: materials, dashboard and the assistant

## Materials

Files: [materials_screen.dart](../../lib/features/materials/screens/materials_screen.dart) · [materials_api.dart](../../lib/features/materials/data/materials_api.dart)

```
Upload → FilePicker.pickFile → UploadFile
  ▼ POST /courses/<id>/materials (multipart)
  ▼ the list reloads

Tap a file → GET /materials/<id> → a private link that dies after 10 minutes
  ▼ launchUrl opens it in the phone's viewer or a browser tab
```

The link is fetched at the moment of the tap, because an old one would have stopped working. `UploadFile` works out the file type from its name, because the backend refuses types it doesn't know.

**Not yet proven:** a real upload needs a real login. This is the first thing to try once a teacher account exists.

## Dashboard

Files: [dashboard_screen.dart](../../lib/features/dashboard/screens/dashboard_screen.dart) · [dashboard_api.dart](../../lib/features/dashboard/data/dashboard_api.dart)

`DashboardApi.load` asks three routes at once. Every number comes from the backend:

| On screen | From |
|---|---|
| Schedule health, Syllabus | `GET /sections/<id>/sessions` → `plan` |
| Attendance | `GET /sections/<id>/attendance` → `average` |
| At risk | The same reply: students below the line |
| Class average per assessment | `GET /sections/<id>/marks` → `assessments[].average` |

`average` was added to those two replies for this screen, because all calculations stay on the server.

**Differs from the design:** the design shows scores per topic. Marks aren't linked to topics, so those numbers don't exist. The screen shows the class average per assessment instead of inventing them.

Chart choices: one series, so no legend; the real number sits beside each bar, so colour is never the only way to read it; a bar turns coral below 50%, the university's pass line. Tapping **At risk** opens the attendance report.

## Assistant (placeholder)

File: [assistant_sheet.dart](../../lib/features/assistant/screens/assistant_sheet.dart)

The button on Home and the course screen opens a sheet saying the assistant is coming. It sends nothing anywhere. The real one is paused; `backend/docs/flows/assistant.md` records where it stopped. When it returns, only this file's sheet needs replacing.
