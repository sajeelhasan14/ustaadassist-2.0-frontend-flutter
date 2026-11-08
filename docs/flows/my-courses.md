# My courses (the first screen)

Added 2026-11-09. Every course is separate: this screen only lists them; everything else happens inside a course.

## What the teacher sees

- **Signed in, with courses:** "Good morning, Sana", the headline "Your courses.", one big card per course (name only), then **New course**.
- **Signed in, no courses yet:** "No courses yet." and one green button, **Create your first course**.

## Trace: opening the app

1. `app.dart` sees a login and shows `MainShell`.
2. `MainShell` opens its first tab, `MyCoursesScreen`.
3. `MyCoursesScreen._load()` sends two requests at the same time:
   - `GET /api/v1/me` → the teacher's name (for the greeting and the initials).
   - `GET /api/v1/courses` → every course.
4. Backend `app/api/v1/courses/route.ts` checks the token, then runs one SQL query:
   courses JOIN semesters WHERE the semester is this teacher's, newest semester first, then by title.
5. The screen draws one `_CourseCard` per course. Tapping one opens `CourseScreen`.
6. Coming back from any screen reloads the list, so a new, renamed or deleted course shows straight away.

## Why one route for all courses

Courses are stored inside semesters (a semester = one start and end date). The old Home asked only for the
**newest** semester's courses, so a course with different dates (for example at a second university)
disappeared from the list. `GET /courses` reads them all in one go.
