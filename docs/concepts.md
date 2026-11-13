# Concepts

Every idea used in the app, explained once in plain words. New ones are added in the step that first uses them.

## Theme

One central set of styling choices (colours, fonts, shapes) that every screen reads from. Like a school uniform policy: you don't tell each student which colour shirt to wear; there's one rule, and changing the rule changes everyone.

In Flutter the theme is a `ThemeData` object given to `MaterialApp`. Built-in widgets read it automatically, so a plain `FilledButton(...)` comes out green and pill-shaped without us styling each one.

## Design token

A named value instead of a raw one: `AppColors.card` instead of `Color(0xFF1E1C19)`. The name says what it is for. If the card colour changes, you edit one line and every card follows. A hex code typed in 40 screens would mean 40 edits, and you'd miss some.

## Package (and `pubspec.yaml`)

A package is code someone else wrote that we add to our app, like a library book you borrow instead of writing it yourself. `pubspec.yaml` is the app's shopping list: it names each package and the version range we accept. `flutter pub add google_fonts` adds a line there and downloads it. `pubspec.lock` records the exact versions downloaded, so every computer gets the same ones.

## `material_ui` vs `package:flutter/material.dart`

Material is Google's set of ready-made widgets (buttons, text fields, cards). It used to be built into Flutter itself. Since Flutter 3.47 it's a separate package, `material_ui`, so it can be updated without waiting for a new Flutter release. The old import still exists, but mixing the two breaks things: it's like two printings of the same form with different form numbers, where the office rejects the old one. We use `package:material_ui/material_ui.dart` everywhere.

## `abstract final class` with `static` members

`AppColors`, `AppText` and `AppTheme` are just named boxes of values. You never create one with `AppColors()`; you read `AppColors.green` directly.
- `abstract` means "you can't create an object of this".
- `final` means "no other class can extend it".
- `static` means "belongs to the class itself, not to an object of it".

## `const` vs `final`

Both mean "never changes after it's set".
- `const`: the value is known when the code is compiled, like a number printed on a form. Colours are `const`.
- `final`: the value is worked out once, when the app runs, like the date filled in when the form is submitted. Fonts from `google_fonts` are `final`, because the package builds the style at run time.

## Login token

A signed pass Supabase gives the app after sign in. The app shows it with every request, like a staff card at the gate, so the password is typed once and never sent to our backend.

## `Future` and `await`

A `Future` is a value that isn't here yet, like an order number while the kitchen cooks. `await` means "wait for it here". `HomeApi.load` starts three requests before waiting, so they cook at the same time.

## `FutureBuilder` and `StreamBuilder`

Widgets that redraw when something arrives. `FutureBuilder` waits for one result, so `AsyncBody` uses it for loading data. `StreamBuilder` listens to a series of events, so `app.dart` uses it to hear every login and logout.

## `StatefulWidget` and `setState`

A widget that remembers things while it's on screen, such as "is the password hidden?". `setState` says "this changed, draw me again". A `StatelessWidget` only shows what it's given.

## `--dart-define-from-file`

Passes settings into the app when it's built. Keeps addresses and keys out of the code, so each computer can have its own and none of them reach git.

## CORS

A browser safety rule: a page may not call a server on a different address unless that server agrees. The app in Chrome is on port 8765 and the API on 3000, so the backend agrees during development only. Phones have no such rule.

## Widget test

A small program that draws a screen without a phone, taps it and checks the result. `phone_width_test.dart` draws screens at phone sizes, because Flutter reports anything that doesn't fit as a failure.

## `Navigator`: push and pushReplacement

The app keeps screens in a stack, like papers on a desk. `push` puts a new one on top, and Back removes it. `pushReplacement` swaps the top one, which setup uses so Back can't return to a step that's already saved.

## `mounted`

After a slow request, the teacher may have left the screen. `mounted` says whether it's still there, so we don't update a screen that's gone. That's why you see `if (!mounted) return;` after `await`.

## Saving progress between steps

Step 1 remembers the course it created. If saving the timetable then fails and the teacher presses Next again, it retries only the timetable, because creating the course a second time would be refused as a duplicate.

## Contrast ratio

How different two colours are in brightness, from 1:1 (identical) to 21:1 (black on white). Text needs at least 4.5:1 to be easy to read; large headings can get by with 3:1. We checked every text/background pair in `app_colors.dart`. For example, white on green is 1.7:1, which is why it's banned.

## Multipart upload

A normal request carries one block of text. A multipart request carries several labelled parts, so a file and its details can travel together, like one envelope holding a letter and a photo. `api.upload` builds these. Each file also states its type, such as `application/pdf`, and the backend refuses types it doesn't accept.

## Bytes

A PDF isn't text, so it can't arrive as JSON. It comes as raw numbers, `Uint8List` in Dart. `api.download` returns those, and `saveFile` hands them over as a file.

## Saving in the background

Doing slow work without making the person wait, as a waiter takes the next order while the kitchen cooks. Marks entry records a mark on screen at once and sends it behind the scenes. The risk is a failed save going unnoticed, so unsaved marks stay in a waiting list until the server confirms them.

## Timeout

How long the app waits before giving up. Normal requests get 30 seconds. AI requests get 200, because the backend may try three models in turn.

## `PopScope`

Lets a screen step in when the teacher presses back, like a shop assistant asking "did you want to pay for that?" at the door. Marks entry uses it to finish saving before closing.

## Share sheet

The phone's built-in "send this to…" panel. One step covers saving, printing and WhatsApp, so the app doesn't need a button for each.

## Fake backend

A pretend server used only in tests, like a flight simulator: the real controls, no real plane. It answers with the same JSON shapes as the real API and records what each screen sends. It proves the app reads and writes those shapes correctly. It can't prove the real server behaves the same, so a real run is still needed.

## Signed link

A private web address that works for a short time, like a visitor's badge that expires. Materials use one that lasts 10 minutes, so files are never public.

## `setState` must not return a `Future`

`setState(() => _data = load())` looks harmless, but the arrow returns what it assigned, and that's a `Future`. Flutter treats this as a mistake and stops in debug mode. Writing it with a block, `setState(() { _data = load(); });`, returns nothing. Every screen that reloads uses the block form.

## Speech recognition

The phone turns spoken words into text, like someone taking dictation. The `speech_to_text` package asks the phone's own service to do this, so the app needs the microphone permission, and the phone asks the teacher first. It works in whatever language the phone is set to.

## Bottom sheet

A panel that slides up over the current screen, like pulling a drawer. The screen behind stays where it was, so closing the assistant puts the teacher back exactly where they were.

## Light and dark mode

The phone has a setting: light or dark. The app reads it and uses the matching colours. Like a classroom with day lights and night lights: same room, same furniture, different lighting. In `app_colors.dart` each colour has both values on one line, `_pick(dark, light)`, and `AppColors.isLight` decides which one comes back.

## Getter

A name that runs a tiny bit of code every time you read it, instead of storing a value once. `static Color get text => ...` works out the text colour fresh each time, so after the phone switches to light mode the same `AppColors.text` gives the light value. A `final` would keep whatever it was the first time, like a photo instead of a window.

## `const`

Tells Dart "this value is fixed forever, build it once when the app is made". `const Icon(color: AppColors.text)` used to be allowed because the colour was fixed. Now the colour depends on the mode, so Dart refuses `const` there, and we removed it in those places.

## Observer (`WidgetsBindingObserver`)

A widget that asks Flutter "tell me when something about the phone changes". `app.dart` is one. When the phone switches light/dark, Flutter calls its `didChangePlatformBrightness()`. Like asking the school office to ring you when the timetable changes, instead of checking every minute.

## Redrawing every widget (`markNeedsBuild`)

Flutter normally only redraws widgets that it knows depend on something that changed. Our screens read `AppColors` directly, so Flutter can't know they depend on the mode. On a mode switch, `app.dart` walks through every widget on screen and marks it "needs a redraw". Unlike restarting the app, this keeps the open screen and anything typed in it.


## Frosted glass (`BackdropFilter`)

A card you can half see through, like a frosted bathroom window: the colours behind it show, but blurred. `BackdropFilter` blurs whatever is already painted behind it. The dock and the glass menu use it. Plain cards don't blur (that would be slow in a long list); they are just see-through, so the glow shows faintly through them.

## Radial gradient (the glow)

A colour strongest at one point and fading to nothing around it, like a torch on a wall. `GlowBackground` paints a green one top-left, a violet one top-right and a faint green one at the bottom.

## Page transition builder

When a new screen opens, Flutter asks the theme "how should it slide in?". We answer with Flutter's normal animation, but with the screen placed on the glow first. That is how every screen gets the glow without each one adding it.

## `ValueNotifier`

A box holding one value that rings a bell when the value changes. `Appearance.choice` is one: the Me screen changes it, and `app.dart` hears the bell and redraws in the new mode.

## Saved on the phone (`SharedPreferences`)

A small notebook the app keeps on the phone that survives closing it. We write two things in it: the Appearance choice and each course's colour. It never leaves the phone, so a second phone starts fresh.

## Route

One layer on the navigator's stack: each screen is a route, and so are dialogs and our glass menu. `PopupRoute` is a see-through layer that closes when you tap outside it. Popping a route can hand a value back: the glass menu hands back the action that was chosen.

## Overlay

A see-through sheet above every screen, where things float that don't belong to one screen. The confetti goes there, so it keeps playing after the attendance screen closes.

## `AnimationController` and ticker

An `AnimationController` is a number that moves from 0 to 1 over a set time, like a stopwatch hand. It needs a ticker, a clock that ticks once per frame; `SingleTickerProviderStateMixin` gives a widget one. The loading shapes and the confetti use it. `TweenAnimationBuilder` (used by `CountUp`) is the shortcut when you just want a value to move once, with no controller.

## `CustomPainter`

Drawing by hand on a canvas: "a circle here, a line there". The progress ring and the confetti are drawn this way, because no ready-made widget draws them.

## Safe delete

Instead of a pop-up "Are you sure?", the Delete line itself turns red and says "Tap again to delete". The second tap deletes; tapping anything else cancels. One less screen to read, same protection. Used where only one item is lost.

## One-time code (OTP)

A short code that works once, like the PIN a bank texts you. For "forgot password" Supabase emails a 6-digit code; typing it in proves the email is yours, so the app may set a new password. We use the code instead of the email's link because a link would have to open the app from a web address (a "deep link"), which needs extra setup on the phone.

## Moving data in a migration

A migration can change the shape of a table *and* move the data into the new shape, in the same file. Holidays used to belong to the teacher; the 2026-11-11 migration copies each one into every course it touches, then removes the old copies. Like moving a school's one shared notice board into a notice board per classroom: every notice is pinned up again in each room it concerns.

## JSON in a column (`jsonb`)

A database column can hold a small structured value, not just one number or word. A course's grade scale is a list like `[{"grade": "A+", "min": 90}, ...]` kept in `courses.grade_scale`. Empty (null) means "use the default scale".
