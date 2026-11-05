# Flow: results and downloads

Files: [results_screen.dart](../../lib/features/results/screens/results_screen.dart) ·
[sheet_details_screen.dart](../../lib/features/results/screens/sheet_details_screen.dart) ·
[download_buttons.dart](../../lib/features/results/widgets/download_buttons.dart) ·
[results_api.dart](../../lib/features/results/data/results_api.dart) ·
[save_file.dart](../../lib/core/save_file.dart)

Nothing is typed here and nothing is stored. The backend works the sheet out from the marks on every request, so change a mark and the sheet follows.

## Trace: downloading the result sheet

```
Results → "PDF" under Result sheet
  ▼ DownloadButtons._download
  ▼ ResultsApi.file → api.download
      GET /sections/<id>/results?format=pdf         bytes, not JSON
  ▼ saveFile(bytes, "Result sheet CS-301 Sec A.pdf")
      browser → a normal download
      phone   → the share sheet: save, open, print or WhatsApp
```

Why the app builds the file name itself: a browser hides the server's file name from the app unless the server opts in, so the name is made here from the same parts.

## The three files

| Button | Route | Holds |
|---|---|---|
| Result sheet | `/sections/<id>/results` | The university format: theory, lab, total in words, grade, remarks |
| Marksheet | `/sections/<id>/marks` | One column per assessment |
| Attendance sheet | `/sections/<id>/attendance` | One column per held class |

The attendance sheet's buttons also appear on the attendance report.

## "Not final"

If some students have some marks but not all, the panel turns amber and says how many. The sheet still downloads; the warning just tells the teacher it isn't finished.

## Sheet details

The lines printed at the top of the sheet. `PATCH /courses/<id>` saves them with the credit hours. They're typed once, because a course without its own details copies the teacher's latest ones. Blank university lines print the University of Karachi wording.

## Try it

1. Enter marks for a few students, leaving one blank.
2. Open **Results**: the panel says `1 NOT FINAL`.
3. Tap **Sheet details**, fill in the department, save.
4. Tap **PDF** and check the header.
