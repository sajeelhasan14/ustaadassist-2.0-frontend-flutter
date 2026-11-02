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
├── app.dart             the app shell: theme + first screen          (step 2)
├── core/                app-wide plumbing; knows nothing about courses or students
│   └── theme/           colours, fonts, radii
├── shared/widgets/      UI pieces used by many features              (step 2+)
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
| `lib/core/theme/app_theme.dart` | `AppTheme.night`: turns colours and text into Flutter's `ThemeData`; `AppRadius`: corner sizes | `app.dart` (step 2) |
| `design_inspo/UstaadAssist UI Design.html` | The design file. Screens 22–37 are the Night versions we build from | you, me |

## Packages

| Package | Why |
|---|---|
| `material_ui` | Flutter's Material widgets (buttons, text fields, cards). Since Flutter 3.47 they live in this package instead of inside Flutter, so we import `package:material_ui/material_ui.dart`, not `package:flutter/material.dart` |
| `google_fonts` | Downloads Bricolage Grotesque, Plus Jakarta Sans and IBM Plex Mono the first time the app runs, then caches them on the phone |

## Design decisions

| Decision | Why |
|---|---|
| Night and Lime palette, accent changed to green #00E676 | Your choice after comparing the four palettes |
| Green only means "act here" (hero panel, main buttons) | Success also used to be green; two greens with different meanings confuse. Success now uses a dimmer green pill plus a check icon |
| Never white text on green | 1.7:1 contrast, unreadable. Dark text only (`onGreen`, `onGreenSoft`) |
| All colours in one file | A light mode for bright classrooms can be added later by editing one place |
| Surfaces separated by tone, not shadows | From the design: ground is darker than cards, cards have no shadow |
