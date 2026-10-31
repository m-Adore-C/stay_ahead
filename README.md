# StayAhead

StayAhead is a workspace app for students to organize course modules, track tasks with due dates, and upload study documents. My data is now saved on the phone with `shared_preferences`, so nothing is lost when the app closes, and it shows motivational quotes and academic study facts from the DummyJSON Quotes & UselessFacts API.

## Screenshots
![Before closing](screenshots/before.png)
![After running again](screenshots/after.png)
![Live data from an API](screenshots/api.png)
![No internet](screenshots/no-internet.png)

---

## Features & UI Mapping

- **Two Screens**: `HomeScreen` for dashboard/task management and `AssignmentDetailsScreen` for viewing/editing notes.
- **`add` Command**: Triggered via `NEW TASK` FAB to open a modal dialog with DatePicker validation.
- **`complete` Command**: Toggled via item checkboxes or details controls. Re-completing an already completed task displays an error message.
- **`list` Command**: Rendered dynamically via `ListView.builder`.
- **`pending` Command**: Handled using a segmented `ToggleButtons` filter (`ALL`, `PENDING`, `COMPLETED`).
- **`report` Command**: Rendered as live metric cards showing `TOTAL`, `PENDING`, and `DONE`.
- **Search & Filter**: Real-time text search and filter segments.
- **Delete Confirmation & Undo**: Dialog verification on deletion with a SnackBar `Undo` action.

---

## Lab 12 Scenario Test Routine

1. Tap `NEW TASK` $\rightarrow$ Add `Database` with due date `2026-10-20`.
2. Tap `NEW TASK` $\rightarrow$ Add `Mobile` with due date `2026-10-18`.
3. Tap `NEW TASK` $\rightarrow$ Add `Networking` with due date `2026-10-25`.
4. Tap `Mobile` checkbox to complete it.
5. Tap `Mobile` checkbox again $\rightarrow$ Displays error: `Error: Mobile is already completed.`.
6. Tap `PENDING` filter chip $\rightarrow$ Shows `Database` and `Networking`.
7. View report cards at top $\rightarrow$ `TOTAL: 3`, `PENDING: 2`, `DONE: 1`.

---

## Think

### 1. Which Lab 12 command was the hardest to turn into a screen, and why?
The `complete` command was the most challenging to transition to UI because in the CLI version, completion was requested by typing a subject string (`complete:Mobile`). On a screen, completing an item can happen via a checkbox, a button inside a list tile, or from a details screen. Handling edge-case validations (such as attempting to re-complete a finished task) while keeping the UI checkbox state synchronized across filters required careful state management inside `setState()`.

### 2. What did you change in your Lab 12 logic once it had a screen, and why?
In the CLI logic, output was printed to stdout sequentially using `print()`. When transitioning to a graphical interface, text output was replaced with persistent reactive state rendering. Commands were refactored from `if/else if` string parsers into direct event handlers attached to widgets (`onPressed`, `onChanged`, `onTap`), and feedback messages were converted from terminal logs into `SnackBar` popups.

---

# Firebase Cloud Integration (Session 6)

StayAhead is fully integrated with **Firebase Cloud services**:
- **Firebase Authentication**: Email and password user registration, login, session persistence, and secure logout.
- **Cloud Firestore**: Real-time cloud database syncing user-specific courses, tasks, and documents live across screens and devices.
- **Firestore Security Rules**: User-isolated data security ensuring each user can only read and write their own documents.

## Session 6 Screenshots

### 1. Authentication (`LoginScreen`)
![Login Screen](screenshots/login.png)
*Email and password authentication screen supporting sign-up, sign-in, input validation, and user feedback.*

### 2. Live Firestore Workspace (`DashboardScreen`)
![Live Data Workspace](screenshots/live.png)
*Real-time reactive dashboard powered by `StreamBuilder` listening to Firestore snapshots (`users/{userId}/courses`).*

### 3. Firebase Console
![Firebase Console](screenshots/console.png)
*Firebase Console displaying registered authentication users and user-scoped Firestore documents.*

### 4. Security Rules Enforcement
![Access Denied / Security Rules](screenshots/denied.png)
*Cloud Firestore security rules validating authentication status and preventing unauthorized access.*

---

## Key Features & Architecture

- **`AuthGate` Navigation**: Uses `FirebaseAuth.instance.authStateChanges()` to automatically route users to either `LoginScreen` or `DashboardScreen`.
- **Real-Time Data Streaming**: `StreamBuilder<List<CourseModule>>` listens to `userCoursesStream()`, immediately reflecting any cloud database updates.
- **User-Isolated Storage**: All data is saved under `/users/{userId}/courses/{courseId}` in Cloud Firestore.
- **Daily Motivation API**: Integrates external quotes and facts APIs with offline error handling and retry mechanisms.

---

## Cloud Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Each user can only read and write their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## Verification & Test Steps

1. Launch application $\rightarrow$ Presented with `LoginScreen`.
2. Enter email and password $\rightarrow$ Tap **Create Account** / **Log In**.
3. Upon authentication, `AuthGate` streams user state and opens `DashboardScreen`.
4. Add a new course module or task $\rightarrow$ Data instantly persists to Cloud Firestore under `/users/{userId}/courses`.
5. Tap the **Logout** icon in the AppBar $\rightarrow$ Session ends and returns to `LoginScreen`.
