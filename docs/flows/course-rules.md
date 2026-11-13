# Course rules, student details, topic import, forgot password

Built 2026-11-11. Every course is separate (decision of 2026-11-09), so a course's rules live in **Course settings**.

## 1. Changing one course's attendance line

```
Course settings → "Attendance line" row → type 80 → Save
  │  _CourseSettingsScreenState._changeLine          lib/features/courses/screens/course_settings_screen.dart
  ▼
CoursesApi.update(courseId, minAttendance: 80)       lib/features/courses/data/courses_api.dart
  ▼
PATCH /api/v1/courses/<id>  { minAttendance: 80 }    backend/app/api/v1/courses/[id]/route.ts
  │  UPDATE courses SET min_attendance = 80 (only if the course is this teacher's)
  ▼
the saved course comes back → the row shows 80%, the course screen gets the new Course
```
From then on `GET /sections/<id>/attendance` (the report, the "fell below the line" warning after saving attendance) and Today's warnings compare with **this course's** line.
A brand-new course starts with the line of the teacher's newest course.

## 2. Changing one course's grade scale

```
Course settings → "Grade scale" → GradeScaleScreen (filled with the current bands)
  │  change "C from 50" to 45 → "Save grade scale"
  │  _bands(): every line has a grade and a %, no grade twice, no % twice, sorted highest first
  ▼
CoursesApi.setGradeScale(courseId, bands)  → PATCH /courses/<id> { gradeScale: [...] }
  │  backend checks the same rules (lib/grades.ts gradeScaleSchema), stores courses.grade_scale
  ▼
GET /sections/<id>/results  → grade = gradeFor(course's scale, %)   (lib/grades.ts)
```
"Use the default scale" sends `gradeScale: null`, so the course follows the default (University of Karachi) bands again.

## 3. One course's holidays

```
Course settings → "Check holidays" → SetupHolidaysScreen
  ▼
SetupApi.offDays(courseId) → GET /off-days?courseId=<id>
  │  adds any public holiday this course doesn't have yet (lib/holidays.ts addPublicHolidays)
  ▼
the list; unticking / adding / moving a day changes this course only
```
When a course is created (`POST /semesters/<id>/courses`), the backend copies in the days the teacher already marked in their other courses for the same dates.

## 4. Opening a student

```
Class list → tap a student
  │  _StudentsScreenState._open              lib/features/students/screens/students_screen.dart
  ▼
StudentDetailsScreen → StudentsApi.details(sectionId, studentId)
  ▼
GET /sections/<id>/students/<studentId>      backend/app/api/v1/sections/[id]/students/[studentId]/route.ts
  │  the student (if in this teacher's section) · held classes they were marked in · each assessment's mark
  ▼
StudentDetailsView: ring + %, "MISSED n CLASSES" with the dates, marks with thin bars, Edit (same dialog as "Add one student")
```

## 5. Reading topics from a photo of the outline

```
Topics step → "Photo of outline" (camera) or "PDF or photo" (files)
  │  _SetupTopicsScreenState._readOutline     lib/features/setup/screens/setup_topics_screen.dart
  ▼
SetupApi.extractTopics(files) → POST /topics/extract (multipart)   backend/app/api/v1/topics/extract/route.ts
  │  the AI lists the topics; numbering, bullets and repeats are removed without AI; nothing saved
  ▼
the topics are added to the box below anything already typed → the teacher checks → Next (saves as before)
```

## 6. Forgot password

```
Sign in → "Forgot password?" → ForgotPasswordScreen (email carried over)
  │  "Send code" → AuthService.sendResetCode → Supabase resetPasswordForEmail
  ▼
email with a 6-digit code (needs {{ .Token }} in Supabase's "Reset password" template)
  │  code + new password → "Save new password"
  ▼
AuthService.resetPassword: verifyOTP(type: recovery) signs in → updateUser(password)
  ▼
app.dart's StreamBuilder hears the sign-in → course list; the screen pops back to it
```
No backend route: like sign in, the password never passes through our server.
