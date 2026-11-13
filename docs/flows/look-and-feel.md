# Look and feel: appearance, glass menu, reward moments

Design source: `UstaadAssist-aurora-light.pdf` and `UstaadAssist-ui-refresh.pdf` (project root). None of these flows needs the backend except where the trace says so.

## 1. The teacher taps "Light" on the Me screen

```
Me screen: tap "Light"
  │  _AppearanceChoice.onTap
  ▼
Appearance.set('light')                      lib/core/theme/appearance.dart
  │  1. choice.value = 'light'  → tells every listener
  │  2. saves 'appearance' = 'light' on the phone (SharedPreferences)
  ▼
_UstaadAssistAppState._redraw                lib/app.dart (was listening to Appearance.choice)
  │  setState → build() runs:
  │    AppColors.isLight = Appearance.isLight(phone brightness)  → true
  │    MaterialApp(theme: AppTheme.current)  → the light ThemeData
  │  then marks every widget on screen "needs a redraw"
  ▼
Every widget builds again and reads AppColors.text, AppColors.card…
  → each getter now returns its light value (_pick(dark, light))
```

Next time the app starts, `main.dart` calls `Appearance.load()` before the first screen, so it opens straight in Light.
"System" works the same way, except `app.dart` also hears the phone switch modes (`didChangePlatformBrightness`).

## 2. A course gets its colour

```
My courses screen opens
  │  _MyCoursesScreenState._load
  ▼
GET /me and GET /courses (together)          backend
  ▼
Appearance.giveCourseColours(ids, oldest first)
  │  a course seen for the first time gets the colour the fewest courses use
  │  saved on the phone as "courseId:index" lines
  ▼
AppColors.courseColour(course.id)            card bar + arrow on My courses,
                                             dot next to the code, attendance bars in the course
```

## 3. Deleting a question from its glass menu

```
Paper screen: tap "⋮" (tooltip "Question options")
  │  GlassMenuButton._open                   lib/shared/widgets/glass_menu.dart
  │  1. finds the button's place on screen and the card around it (_rowAround)
  │  2. pushes _GlassMenuRoute: blur + dim over the screen with a hole for that card,
  │     the frosted menu card next to the button
  ▼
tap "Delete"  → it turns red: "Tap again to delete"   (nothing sent yet)
tap again     → the route closes and hands back the item's onTap
  ▼
_PaperScreenState._removeQuestion            lib/features/papers/screens/paper_screen.dart
  ▼
PapersApi.removeQuestion → DELETE /questions/:id      backend
  ▼
the paper reloads without the question
```

Tapping anywhere outside the menu closes it and does nothing.

## 4. Saving attendance (the reward moment)

```
Take attendance: tap "Submit attendance"
  │  _TakeAttendanceScreenState._save
  ▼
AttendanceApi.save → PUT /sessions/:id/attendance     backend
  ▼
_warnIfShort (may show "fell below the line")
  ▼
celebrate(context, message: 'Attendance saved · 46 present', onUndo: …)
  │  lib/shared/widgets/celebrate.dart
  │  1. confetti into the app's top layer (root Overlay), 1.4 s, then removes itself
  │  2. the Saved toast in the app-wide ScaffoldMessenger
  │     Undo is there only if this class was marked before:
  │     it saves the old absent list and topics again (same PUT)
  ▼
Navigator.pop → the course or classes screen reloads; the toast and confetti carry on over it
```

Marks entry does the same when the teacher reaches the last student and every mark has been saved, without Undo (any mark can be changed by opening the sheet again).
Teachers who turned animations off on their phone get the toast without confetti, and still loading shapes.
