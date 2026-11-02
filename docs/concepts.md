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

## Contrast ratio

How different two colours are in brightness, from 1:1 (identical) to 21:1 (black on white). Text needs at least 4.5:1 to be easy to read; large headings can get by with 3:1. We checked every text/background pair in `app_colors.dart`. For example, white on green is 1.7:1, which is why it's banned.
