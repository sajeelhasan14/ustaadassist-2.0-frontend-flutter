# UstaadAssist app: Architecture

The Flutter app teachers use on their phones. This guide grows with the code: every step that adds a file or folder updates it.

## The big picture

```
 Flutter app (this folder)
        │  HTTPS + login token
        ▼
 Next.js API  (../backend, /api/v1/*)  ──►  Supabase PostgreSQL
```

- **The app never touches the database.** Every read and write goes through the backend API, which checks the login and does all calculations (attendance %, totals, plans). The one exception: logging in goes straight to Supabase Auth.
- **The app shows data and collects taps.** If something needs to be calculated, the backend does it.

## How `lib/` is organised

The app is split by **feature** (one folder per part of the app) plus two shared folders. Each folder has one kind of job:

```
lib/
├── main.dart            starts the app
├── app.dart             the app shell: theme, and logged in or out
├── core/                app-wide plumbing; knows nothing about courses or students
│   ├── config.dart      server address and Supabase keys
│   ├── api/             the one client that talks to the backend
│   └── theme/           colours, fonts, radii
├── shared/widgets/      UI pieces used by many features
└── features/<name>/     one part of the app (home, attendance, marks…)
    ├── data/            that feature's API calls + data classes
    ├── screens/         full pages
    └── widgets/         pieces only this feature uses
```

**Rules:**
- A screen never writes a colour, font size or radius itself. It uses `AppColors`, `AppText` and `AppRadius`.
- A screen never calls the API directly. It asks its feature's `data/` code.
- `core/` and `shared/` never import from `features/`. Features import from them, not the other way round.
- We separate concerns without heavy patterns: no repository, use-case or BLoC layers unless we decide we need them.

## Files

| Path | Job | Used by |
|---|---|---|
| `lib/core/theme/app_colors.dart` | `AppColors`: every colour by name (ground, card, green, status colours) | every screen and widget, `app_theme.dart` |
| `lib/core/theme/app_text.dart` | `AppText`: every text style by job (screen title, body, mono…) | every screen and widget, `app_theme.dart` |
| `lib/core/theme/app_theme.dart` | `AppTheme.night`: turns colours and text into Flutter's `ThemeData`; `AppRadius`: corner sizes | `app.dart` |
| `lib/core/config.dart` | `Config`: reads the settings from `dart_defines.json` | `main.dart`, `api_client.dart` |
| `lib/core/api/api_client.dart` | `api`: sends requests with the login token. `ApiException`: any failure, in readable words | every feature's `data/` code |
| `lib/shared/widgets/hero_panel.dart` | The big coloured panel | screens |
| `lib/shared/widgets/status_pill.dart` | Small status label such as "Done" | screens |
| `lib/shared/widgets/async_body.dart` | Loading spinner, error with "Try again", then the screen | every screen that loads data |
| `lib/features/auth/data/auth_service.dart` | Sign in, sign up, sign out, straight to Supabase | auth screens, `app.dart`, Me |
| `lib/features/auth/screens/` | Welcome, Sign in, Sign up | `app.dart` |
| `lib/features/home/data/home_api.dart` | Loads today's classes and courses | Home |
| `lib/features/home/screens/main_shell.dart` | The bottom tabs | `app.dart` |
| `lib/features/home/screens/home_screen.dart` | Today at a glance | `main_shell.dart` |
| `lib/features/profile/screens/me_screen.dart` | The account tab | `main_shell.dart` |
| `lib/core/dates.dart` | Dates as text: `isoDate`, `shortDate`, `longDate` | screens that show dates |
| `lib/shared/widgets/step_scaffold.dart` | The frame of a step-by-step flow: step pill, two-line heading, one main button | setup screens |
| `lib/features/setup/data/setup_api.dart` | Finds or creates the semester, creates the course, saves timetable, topics and holidays | setup screens |
| `lib/features/setup/screens/` | The three steps: basics, topics, holidays | Home, course screen |
| `lib/features/courses/data/courses_api.dart` | `Course`, `Section`, `SectionPlan`. Loads a course's sections and plan | Home, course screen, setup |
| `lib/features/courses/screens/course_screen.dart` | One course: where the plan stands, and its topics | Home, setup |
| `lib/core/save_file.dart` | `saveFile`: hands a finished file to the teacher (download in a browser, share sheet on a phone) | results, papers |
| `lib/shared/widgets/card_list.dart` | Rows in one rounded card with lines between them | most lists |
| `lib/shared/widgets/empty_note.dart` | Says why a list is empty, with one action | most lists |
| `lib/shared/widgets/prompts.dart` | `showMessage`, `confirmAction`, `askText`, `markText` | most screens |
| `lib/features/courses/screens/course_settings_screen.dart` | Name, code, sections, timetable, holidays, delete | course screen |
| `lib/features/setup/widgets/timetable_editor.dart` | Class days and times, plus `ValueBox` | setup step 1, course settings |
| `lib/features/attendance/` | Class list, taking attendance, the report, extra classes. [Flow](flows/attendance.md) | Home, course screen, plan, dashboard |
| `lib/features/students/` | Class list, capture, check before saving. [Flow](flows/students.md) | course screen |
| `lib/features/marks/` | Assessments and the number pad. [Flow](flows/marks.md) | course screen |
| `lib/features/papers/` | The paper, AI generation, question editor. [Flow](flows/question-papers.md) | assessments screen |
| `lib/features/results/` | Result sheet, sheet details, download buttons. [Flow](flows/results.md) | course screen, attendance report |
| `lib/features/materials/` | Course files. [Flow](flows/materials-dashboard.md) | course screen |
| `lib/features/plan/` | Weeks, outline, fixing a shortfall. [Flow](flows/plan.md) | course screen |
| `lib/features/dashboard/` | How a section is doing. [Flow](flows/materials-dashboard.md) | course screen |
| `lib/features/assistant/` | The assistant button, chat, voice and Confirm cards. [Flow](flows/materials-dashboard.md) | Home, course screen |
| `lib/features/profile/` | The Me screen and the attendance line | main shell |
| `test/support/fake_backend.dart` | A stand-in API with the real reply shapes, used to drive every screen in tests | `test/` |
| `dart_defines.json` | Your local settings. Not in git; copy `dart_defines.example.json` | `flutter run` |
| `design_inspo/UstaadAssist UI Design.html` | The design file. Screens 22–37 are the Night versions we build from | you, me |

## How the screens connect

```
Home ──► Take attendance (today's classes)
  └────► Course screen, for the section chosen there
            ├── Attendance ──► Take attendance, Report
            ├── Students ────► Capture list ──► Check the list
            ├── Marks ───────► Number pad
            ├── Question papers ──► Paper ──► Generate, Edit question
            ├── Results ─────► Sheet details
            ├── Materials
            ├── Plan ────────► Fix the plan
            ├── Dashboard
            └── Settings ────► Holidays
```

The course screen is the hub, so two bottom tabs are enough. The design's five-tab bar needed a course already chosen, and a teacher has several.

## Running it

1. In `backend/`: `npm run dev`
2. In `frontend/`: `flutter run -d chrome --web-port 8765 --dart-define-from-file=dart_defines.json`

On a real phone, change `API_URL` in `dart_defines.json` to your computer's network address, for example `http://192.168.100.7:3000/api/v1`. `localhost` on a phone means the phone itself.

## Flow: signing in

```
Sign in button
  ▼ AuthService.signIn          straight to Supabase, the backend never sees the password
Supabase saves the session on the device
  ▼ AuthService.changes fires
app.dart rebuilds               logged in → MainShell
  ▼ HomeScreen → HomeApi.load
api_client.dart adds "Authorization: Bearer <token>"
  ▼ GET /me, /today, /semesters at the same time, then the newest semester's courses
Backend checks the token, reads the database, replies
  ▼ AsyncBody swaps the spinner for HomeView
```

## Flow: adding a course

```
Home "New course"
  ▼ Step 1, SetupBasicsScreen           dates pre-filled from the latest semester
SetupApi.semesterFor                    same dates → same semester, else POST /semesters
SetupApi.createCourse                   POST /semesters/<id>/courses, also makes section "A"
SetupApi.saveTimetable                  PUT /sections/<id>/timetable
  ▼ Step 2, SetupTopicsScreen           cleans numbers and bullets off each pasted line
SetupApi.classesAvailable               GET /sections/<id>/sessions, holidays already out
SetupApi.addTopics                      POST /courses/<id>/topics { titles, spreadOver }
  ▼ Step 3, SetupHolidaysScreen         GET /off-days adds the public holidays
Unticked ones                           DELETE /off-days/<id>, only when "Generate my plan" is tapped
  ▼ CourseScreen                        GET /courses/<id>/sections, GET /sections/<id>/sessions
```

Holidays apply to all of a teacher's classes, so unticking one affects their other courses too.

If the teacher leaves halfway, the course stays. Its screen shows "No plan yet" with an Add topics button.

## Packages

| Package | Why |
|---|---|
| `material_ui` | Flutter's Material widgets (buttons, text fields, cards). Since Flutter 3.47 they live in this package instead of inside Flutter, so we import `package:material_ui/material_ui.dart`, not `package:flutter/material.dart` |
| `google_fonts` | Downloads Bricolage Grotesque, Plus Jakarta Sans and IBM Plex Mono the first time the app runs, then caches them on the phone |
| `supabase_flutter` | Login, and remembering it between app launches |
| `http` | Sends requests to the backend |

## Design decisions

| Decision | Why |
|---|---|
| Night and Lime palette, accent changed to green #00E676 | Your choice after comparing the four palettes |
| Green only means "act here" (hero panel, main buttons) | Success also used to be green; two greens with different meanings confuse. Success now uses a dimmer green pill plus a check icon |
| Never white text on green | 1.7:1 contrast, unreadable. Dark text only (`onGreen`, `onGreenSoft`) |
| All colours in one file | A light mode for bright classrooms can be added later by editing one place |
| Surfaces separated by tone, not shadows | From the design: ground is darker than cards, cards have no shadow |

## Flows

Each feature's trace, from button to database and back, is in [docs/flows/](flows/): [attendance](flows/attendance.md), [students](flows/students.md), [marks](flows/marks.md), [question papers](flows/question-papers.md), [results](flows/results.md), [plan](flows/plan.md), [materials, dashboard and assistant](flows/materials-dashboard.md).
