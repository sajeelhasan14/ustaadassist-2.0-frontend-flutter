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
├── app.dart             the app shell: theme (Appearance: System / Light / Dark), and logged in or out
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
| `lib/core/theme/app_colors.dart` | `AppColors`: every colour by name (ground, card, green, status colours), each with a dark and a light value. `isLight` picks which | every screen and widget, `app_theme.dart` |
| `lib/core/theme/app_text.dart` | `AppText`: every text style by job (screen title, body, mono…) | every screen and widget, `app_theme.dart` |
| `lib/core/theme/app_theme.dart` | `AppTheme.current`: turns colours and text into Flutter's `ThemeData` for the current mode. `AppRadius`: corner sizes. `AppGlass`: the frosted-glass card look. `GlowBackground`: the ground plus green and violet glow, put behind every page by the theme's page animation | `app.dart`, every screen with a card |
| `lib/core/theme/appearance.dart` | `Appearance`: the System / Light / Dark choice and each course's colour, both saved on the phone (shared_preferences) | `main.dart`, `app.dart`, Me, My courses |
| `lib/core/config.dart` | `Config`: reads the settings from `dart_defines.json` | `main.dart`, `api_client.dart` |
| `lib/core/api/api_client.dart` | `api`: sends requests with the login token. `ApiException`: any failure, in readable words | every feature's `data/` code |
| `lib/shared/widgets/hero_panel.dart` | The big coloured panel | screens |
| `lib/shared/widgets/status_pill.dart` | Small status label such as "Done" | screens |
| `lib/shared/widgets/async_body.dart` | Loading shapes (pulsing grey blocks), error with "Try again", then the screen | every screen that loads data |
| `lib/shared/widgets/glass_menu.dart` | `GlassMenuButton`: the "⋮" menu as a frosted card, the screen behind blurred except the tapped row, Delete apart in red and asking "Tap again to delete" | every screen with a row menu |
| `lib/shared/widgets/celebrate.dart` | `celebrate`: confetti plus the Saved toast (with Undo when possible). `CountUp`: a number that counts up. `DoneStamp`: the rotated "ALL DONE!" stamp | attendance, marks, course screen |
| `lib/shared/widgets/progress_shapes.dart` | `SegmentBar`: one block per topic. `ProgressRing`: a circle that fills to a % | course screen |
| `lib/features/auth/data/auth_service.dart` | Sign in, sign up, sign out, straight to Supabase | auth screens, `app.dart`, Me |
| `lib/features/auth/screens/` | Welcome, Sign in, Sign up | `app.dart` |
| `lib/features/home/data/home_api.dart` | Loads today's classes and courses | Home |
| `lib/features/home/screens/main_shell.dart` | The floating dock: **Courses** and Me. The open tab is a green pill with its name | `app.dart` |
| `lib/features/home/screens/my_courses_screen.dart` | The first screen: every course by name (one `GET /courses`), **New course**, and "Create your first course" for a new teacher. [Flow](flows/my-courses.md) | `main_shell.dart` |
| `lib/features/home/screens/home_screen.dart` | Today at a glance. **Not shown since 2026-11-09**; its parts move inside each course in the next step | nothing yet |
| `lib/features/profile/screens/me_screen.dart` | The account tab: your name and email, **Appearance** (System / Light / Dark), sign out. A course's rules are in its settings | `main_shell.dart` |
| `lib/features/profile/data/profile_api.dart` | `ProfileApi.me`: name and email of the signed-in teacher (`GET /me`) | Me |
| `lib/features/courses/screens/grade_scale_screen.dart` | One course's grade scale: each grade and the % it starts at, below the last = F; "Use the default scale". [Flow](flows/course-rules.md) | Course settings |
| `lib/features/students/screens/student_details_screen.dart` | One student: attendance ring and %, the dates they missed, every mark, Edit. [Flow](flows/course-rules.md) | the class list |
| `lib/features/auth/screens/forgot_password_screen.dart` | Forgot password: email → 6-digit code from the email → new password, then signed in. [Flow](flows/course-rules.md) | Sign in |
| `lib/core/dates.dart` | Dates as text: `isoDate`, `shortDate`, `longDate` | screens that show dates |
| `lib/shared/widgets/step_scaffold.dart` | The frame of a step-by-step flow: step pill, two-line heading, one main button | setup screens |
| `lib/features/setup/data/setup_api.dart` | Finds or creates the semester, creates the course, saves timetable, topics and holidays | setup screens |
| `lib/features/setup/screens/` | The three steps: basics, topics, holidays | Home, course screen |
| `lib/features/courses/data/courses_api.dart` | `Course`, `Section`, `SectionPlan`. Loads a course's sections and plan | Home, course screen, setup |
| `lib/features/courses/screens/course_screen.dart` | One course as a bento: status tile with the giant "classes left" and the next class, average attendance with mini bars, topics ring, syllabus segments; then the tools and topics | My courses, setup |
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
| Aurora Glass palette, dark and light (2026-11-10, `UstaadAssist-aurora-light.pdf`) | Replaced Night and Lime: cool blue-black #06080A instead of muddy brown-black; light version #EEF2F5 for bright classrooms. The app follows the phone's light/dark setting |
| Green fill vs green words | Bright #00E676 stays on buttons and panels (dark text on it). Green words, icons and thin lines use `greenText`, which is #00803F in light mode because bright green on white is 1.6:1 |
| Violet and red: fills fixed, words deeper | Big violet/red panels keep the same colour in both modes with dark text. Their words and pills (`warningText`, `dangerText`) go a step deeper in light mode so they stay readable on white |
| Dark button on a coloured panel | Near-black fill with the panel's colour as the words (green on the green panel, violet on violet), the same in both modes |
| Green only means "act here" (hero panel, main buttons) | Success also used to be green; two greens with different meanings confuse. Success now uses a dimmer green pill plus a check icon |
| Never white text on green | 1.7:1 contrast, unreadable. Dark text only (`onGreen`, `onGreenSoft`) |
| All colours in one file | The light mode was added by editing this one file plus removing `const` where screens used a colour |
| Glass cards | Cards are see-through (6% white dark, 74% white light) with a thin light edge, so the glow shows through. Light mode adds a soft shadow. Dialogs, sheets and messages use the solid `sheet` colour, or the screen behind would show through their words |
| Glow through the page animation | Every page gets `GlowBackground` from the theme's `pageTransitionsTheme`, so no screen adds it and it moves with the page during the slide-in |
| Floating dock with two tabs | The design's dock had a sparkle button for the assistant; it stays inside each course instead, because the assistant only ever works on one course |
| Bento inside the course, not on a Today home | A "3 classes today" home would mix courses on one screen, which the 2026-11-09 decision rules out. The same tiles live inside each course, from data the screen already loads |
| A colour per course, kept on the phone | Worked out from the id would clash (4 colours: two of three courses are often the same). So the first time a course is seen it gets the least-used colour, saved with shared_preferences. Another phone may pick different colours |
| Safe delete instead of a dialog | Deleting one file, question or topic from a menu takes a second tap ("Tap again to delete"). Deletes that take more with them (an assessment's marks, a paper section's questions, a whole paper, a course section) keep their dialog, which says what is lost |
| Every course keeps its own rules (2026-11-11) | Attendance line, grade scale and holidays live in Course settings, not on Me, because a teacher may teach at two universities with different rules. A new course starts with the line and holidays of the teacher's other courses, so nothing is set twice |
| Forgot password by code, not link | The reset email's link would need the phone to open the app from a web address (deep links, not set up). A 6-digit code typed in the app needs nothing extra. Supabase's "Reset password" email must show `{{ .Token }}` |
| Topic import fills the box, never saves | The AI can misread a photo, so the topics it finds go into the same box the teacher types in, to check before pressing Next |
| Undo only after editing attendance | Saving replaces the whole absent list, so Undo puts the old list back. A class saved for the first time can't be un-marked, so it gets the celebration without Undo |

## Flows

Each feature's trace, from button to database and back, is in [docs/flows/](flows/): [look and feel (appearance, glass menu, rewards)](flows/look-and-feel.md), [course rules, student details, topic import, forgot password](flows/course-rules.md), [attendance](flows/attendance.md), [students](flows/students.md), [marks](flows/marks.md), [question papers](flows/question-papers.md), [results](flows/results.md), [plan](flows/plan.md), [materials, dashboard and assistant](flows/materials-dashboard.md).
