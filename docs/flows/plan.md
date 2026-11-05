# Flow: the teaching plan

Files: [plan_screen.dart](../../lib/features/plan/screens/plan_screen.dart) ·
[fix_plan_screen.dart](../../lib/features/plan/screens/fix_plan_screen.dart) ·
[plan_api.dart](../../lib/features/plan/data/plan_api.dart)

The backend works the plan out on every request, so there is no "Replan" button. Cancel a class or move a holiday, and the next load shows the new plan.

## Trace: opening the plan

```
Course → Plan
  ▼ PlanScreen → GET /sections/<id>/sessions        calendar and plan in one reply
  ▼ PlanWeek.from(sessions) groups classes by the Monday of their week
  ▼ opens on the week holding today
Chips W1, W2… change the week.  "Take" on a class opens attendance.
```

The outline below the week edits topics: tap to rename or change its classes, ⋮ to move or delete. Moving sends every topic id in the new order (`PUT /courses/<id>/topics`).

## Trace: not enough classes

```
Plan panel says "3 classes short" → "Fix it"
  ▼ FixPlanScreen → PlanApi.shortenSuggestion / dropSuggestion work out the options
Teacher picks one
  ▼ Shorten topics → PATCH /topics/<id> { classesNeeded } for each
    Drop topics    → asks first, then DELETE /topics/<id> for each
    Make-up class  → ExtraClassDialog → POST /sections/<id>/sessions
```

| Option | What it changes | Limits |
|---|---|---|
| Shorten topics | Takes classes off the last unfinished topics | Each keeps at least one class still to teach |
| Drop topics | Removes the last topics nobody has started | Never touches a started or finished topic |
| Make-up class | Adds one class | The date must be inside the semester |

The app starts on the gentlest option available. Shortening may not close the whole gap, and the card says how many classes it saves. Classes already held are never touched.

## Try it

1. Open **Plan** and tap a topic. Raise its classes well past what's left.
2. The panel turns amber: `N classes short`.
3. Tap **Fix it**, pick **Shorten topics**, confirm, and the plan is back on track.
