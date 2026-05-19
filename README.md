<div align="center">

# ⚡ GoalPulse

### Enterprise Goal Setting & Performance Tracking Portal

**Built for AtomQuest Hackathon 1.0**

[![Flutter](https://img.shields.io/badge/Frontend-Flutter%20Web-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Firebase](https://img.shields.io/badge/Database-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini](https://img.shields.io/badge/AI-Gemini%201.5%20Flash-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://deepmind.google/technologies/gemini/)

---

*From scattered spreadsheets to structured, AI-augmented performance clarity —*
*GoalPulse is the single system your organisation actually needs.*

---

</div>

---

## 📌 Table of Contents

- [What is GoalPulse?](#-what-is-goalpulse)
- [Core Innovations](#-core-innovations)
- [Live Demo & Credentials](#-live-demo--credentials)
- [Feature Overview](#-feature-overview)
- [User Roles](#-user-roles)
- [Screenshots](#-screenshots)
- [Tech Stack](#-tech-stack)
- [Architecture Overview](#-architecture-overview)
- [Getting Started](#-getting-started)
- [Environment Variables](#-environment-variables)
- [Running Locally](#-running-locally)
- [Deployment](#-deployment)
- [API Documentation](#-api-documentation)
- [Database Schema](#-database-schema)
- [Validation Rules](#-validation-rules)
- [AI Features Deep Dive](#-ai-features-deep-dive)
- [Project Structure](#-project-structure)
- [Roadmap](#-roadmap)
- [Team](#-team)

---

## 🎯 What is GoalPulse?

GoalPulse is a **full-stack, AI-augmented enterprise performance management portal** that digitises the complete lifecycle of employee goal setting and tracking — from structured creation through quarterly achievement check-ins to analytics and audit-ready reporting.

Most organisations manage employee goals through a painful combination of Excel sheets, email chains, and disconnected HR tools. GoalPulse replaces that chaos with:

- A **structured, validated goal-setting workflow** with real-time enforcement of business rules
- A **multi-stage approval pipeline** between employees and managers, with inline editing and goal locking
- **Quarterly check-in cycles** that automatically compute achievement scores per measurement type
- **Shared/departmental KPIs** that synchronise actuals across all linked employee sheets in real time
- **AI-powered features** including goal suggestions, performance summaries, risk prediction, and KPI recommendations — all powered by Google Gemini
- **Enterprise-grade dashboards** with heatmaps, QoQ trends, manager effectiveness metrics, and exportable reports
- A **complete audit trail** for every post-lock change to goal data, satisfying governance requirements

GoalPulse is built with a clean three-role model: **Employee**, **Manager (L1)**, and **Admin/HR** — each with a distinct, purpose-built interface and strict access controls.

---

## 🚀 Core Innovations

These are the architectural and product decisions that make GoalPulse meaningfully different from generic task trackers or template-based appraisal tools.

---

### 1. 🔒 Real-Time Validation Engine with Goal Locking

GoalPulse enforces three non-negotiable business rules simultaneously in real time — both on the frontend and as a defence layer in the backend:

- **Maximum 8 goals** per employee per cycle
- **Minimum 10% weightage** per individual goal
- **Total weightage must equal exactly 100%** — not 99%, not 101%

The live **Weightage Meter** bar turns red the moment the total drifts from 100%, and the Submit button is physically disabled until the sheet is valid. On the backend, every write endpoint re-validates these rules independently, making it impossible to bypass via direct API calls.

Once a Manager approves a goal sheet, **every goal item is individually locked** at the database level (`isLocked: true` per GoalItem). Edits to locked goals require an Admin unlock — which triggers an automatic, immutable audit log entry. This two-layer locking (UI block + Firestore-level field lock) is the kind of data integrity most HR tools skip entirely.

---

### 2. 🔄 Atomic Shared Goal Synchronisation

GoalPulse introduces a **shared goal ownership model** that solves a real problem in team-based performance management: how do you track a departmental KPI (e.g. "Team achieves ₹1.2 Cr revenue") across multiple individual goal sheets without duplicating data entry?

The solution:

- A Manager or Admin creates a **Shared Goal** once — setting the title, description, UoM, and target. These fields are read-only for all recipients.
- The shared goal is **injected into each recipient's goal sheet** as a linked GoalItem. Recipients can only adjust their individual weightage.
- One employee is designated as the **primary owner** of achievement data for that goal.
- When the owner submits quarterly actuals, GoalPulse uses a **Firestore batch write** to propagate the actual achievement value and computed progress score to every linked goal sheet atomically. If any write in the batch fails, the entire sync is rolled back.

This means managers get consistent, single-source achievement data across the whole team for shared objectives — with zero manual reconciliation.

---

### 3. 🧮 Multi-Type UoM Progress Score Engine

Different business goals are measured differently. A "Zero incidents" goal is not scored the same way as a "Revenue growth" goal. GoalPulse implements **six distinct Unit of Measurement types**, each with its own progress score formula:

| UoM Type | Direction | Formula |
|---|---|---|
| Numeric Min | Higher is better | `(Actual ÷ Target) × 100` |
| Numeric Max | Lower is better | `(Target ÷ Actual) × 100` |
| Percent Min | Higher % is better | `(Actual ÷ Target) × 100` |
| Percent Max | Lower % is better | `(Target ÷ Actual) × 100` |
| Timeline | Complete by deadline | `100 if on time, else proportional penalty` |
| Zero | Zero = perfect | `100 if Actual = 0, else 0` |

All scores are capped at 100% and can never go negative. The engine runs both client-side (for instant UI feedback in the check-in form) and server-side (as the authoritative computed value stored in Firestore). Division-by-zero and edge cases are explicitly handled.

---

### 4. 🤖 Contextual AI throughout the Workflow

GoalPulse doesn't bolt AI on as a gimmick — it integrates Gemini at four specific points where it genuinely reduces friction:

**Goal Suggestion Assistant:** When an employee is struggling to define a goal for a given Thrust Area, they can invoke the AI drawer. Gemini receives their role, department, and selected thrust area, and returns three concrete SMART goal suggestions — each with a title, description, recommended UoM type, suggested target, and a one-line rationale. One tap applies all values to the goal card.

**Smart KPI Hint:** As an employee types a goal title, a debounced call (500ms) asks Gemini to recommend the most appropriate UoM type and ballpark target. This appears as an unobtrusive inline hint — "💡 AI suggests: Higher is Better (Numeric) — Target ≈ 50,000" — with an "Apply" button. No modal, no disruption.

**Quarterly Summary Generator:** After submitting quarterly actuals, employees and managers can generate an AI-written 4–5 sentence performance narrative. The prompt includes actual vs. target data, UoM context, and the manager's check-in comment. The result reads like a human-written appraisal note, not boilerplate. It's saved to the check-in record and visible in the progress history.

**Goal Risk Prediction:** After Q1 and Q2 check-ins are submitted, GoalPulse projects each goal's end-of-year trajectory by extrapolating from current actuals. Goals are classified as Low, Medium, or High risk — and for Medium/High risks, Gemini generates a one-sentence actionable recommendation for the manager. These surface as AI Risk Alerts on the Manager Dashboard.

---

### 5. 📊 Role-Differentiated Analytics with Heatmap Completion Grid

GoalPulse builds three distinct analytics layers — not a single dashboard shown to everyone:

**Employee:** Personal progress score trend (Q1→Q4 line chart), goal-by-goal Planned vs. Actual comparison, and AI-generated summaries per quarter.

**Manager:** A team completion **heatmap grid** (employees × quarters, green gradient intensity = completion rate), QoQ average score trend, at-risk goal alerts, and a goal status distribution chart. The heatmap is the single most useful view for a manager who needs to see the whole team's health at a glance.

**Admin/HR:** Org-wide heatmap (departments × quarters), a **Manager Effectiveness leaderboard** (ranked by check-in completion rate + avg team score + approval turnaround time), Thrust Area distribution, and the goal sheet funnel (Drafted → Submitted → Approved → Check-ins Complete). Everything is exportable as CSV or Excel.

---

### 6. 🛡️ Governance-Grade Audit Trail

Every post-lock change to goal data — whether an Admin unlocks a goal, a Manager edits a target during approval, or actuals are synced from a shared goal owner — is recorded in an **immutable audit_logs Firestore collection** with:

- Actor identity and role
- The specific field changed (not just "goal updated")
- Old value and new value
- Mandatory reason text (for unlock operations)
- Precise timestamp

The audit log is append-only by design (no update or delete operations allowed on it, enforced at the Firestore security rules level). Admins can filter, paginate, and export the full audit trail as CSV — making GoalPulse suitable for organisations that need HR compliance records.

---

### 7. ⚡ Firestore Real-Time Architecture

GoalPulse uses Firestore's real-time listeners (not polling) for two critical pieces:

- **Notification bell:** The unread notification count and panel content update instantly when a new notification document is written — no page refresh needed.
- **Goal sheet status:** When a Manager approves or returns a goal sheet, the employee's dashboard updates in real time via a StreamProvider listening to their goals document.

This reactive architecture means zero manual refresh during the demo — state changes cascade through the UI automatically.

---

## 🔐 Live Demo & Credentials

> The following accounts are pre-seeded with realistic data across all app states.
> No registration required — just log in and explore.

---

### 🌐 Demo URL

```
https://goalpulse.web.app
```

---

### 👤 Demo Accounts

| Role | Email | Password | Pre-loaded State |
|:---|:---|:---|:---|
| 🛡️ **Admin / HR** | `admin@demo.com` | `Demo@1234` | Full org view, 2 audit log entries, active cycle configured |
| 👔 **Manager** | `manager@demo.com` | `Demo@1234` | 3 direct reports, 1 pending approval, team Q1 actuals visible |
| 👩‍💼 **Employee 1** | `emp1@demo.com` | `Demo@1234` | Goals approved & locked, Q1 actuals submitted, AI summary generated |
| 👨‍💼 **Employee 2** | `emp2@demo.com` | `Demo@1234` | Goal sheet submitted — awaiting manager approval |
| 👩‍💼 **Employee 3** | `emp3@demo.com` | `Demo@1234` | Goal sheet in draft — 2 goals added, weightage incomplete |

---

### 🎬 Recommended Demo Sequence

For the best judge demo experience, follow this 12-minute sequence:

```
1. Login as emp1@demo.com        → Show approved goal sheet + Q1 actuals + AI summary
2. Login as manager@demo.com     → Approve emp2's sheet → Push shared KPI → Review check-in
3. Login as admin@demo.com       → Org dashboard → Unlock a goal → View audit log → Export report
```

> 💡 **Tip:** Keep all three browser tabs open simultaneously to switch roles instantly during the demo.

---

## ✨ Feature Overview

### Must-Have Features (BRD Phase 1 & 2)

- [x] Goal sheet creation with up to 8 goals per cycle
- [x] Real-time weightage validation (total = 100%, each ≥ 10%)
- [x] Goal submission for Manager review
- [x] Manager approval with inline target/weightage editing
- [x] Goal return with mandatory feedback comment
- [x] Goal locking on approval (field-level, not just status)
- [x] Quarterly check-in actuals entry (Q1–Q4)
- [x] Six UoM type progress score computation engine
- [x] Manager check-in review and structured comment
- [x] Shared goal push with atomic actuals synchronisation
- [x] Quarterly window enforcement via cycle configuration
- [x] Achievement report export (CSV + Excel)
- [x] Completion dashboard (employee × quarter grid)
- [x] Immutable audit trail with actor, field, old/new value, reason
- [x] Firebase Auth with custom claim role routing
- [x] Three pre-seeded demo role accounts

### High-Priority Features

- [x] Escalation rules configuration (Admin)
- [x] In-app real-time notifications (Firestore streaming)
- [x] Email notification stubs (logged in dev, SendGrid in production)
- [x] QoQ trend analytics (line charts)
- [x] Department completion heatmap
- [x] Manager effectiveness leaderboard

### AI-Powered Features

- [x] AI Goal Suggestion Assistant (Gemini 1.5 Flash)
- [x] AI Quarterly Summary Generator (Gemini 1.5 Flash)
- [x] Goal Risk Prediction with trajectory analysis
- [x] Smart KPI inline recommendations (debounced, non-intrusive)

---

## 👥 User Roles

### 🟣 Employee
The individual contributor who owns and tracks their own performance.

**Can do:**
- Create, edit, and delete goals (pre-submission only)
- Submit goal sheet for Manager review
- Log quarterly actual achievements (within open windows)
- Adjust weightage on shared goals (only field editable)
- Generate AI performance summaries
- View own locked goals, progress history, and check-in comments

**Cannot do:**
- Edit goals after Manager approval (without Admin unlock)
- View other employees' goal sheets
- Access manager or admin dashboards

---

### 🔵 Manager (L1)
The line manager responsible for team goal quality and quarterly review.

**Can do:**
- Review and approve or return submitted goal sheets
- Inline-edit target values and weightages during review
- Push shared/departmental KPIs to one or more team members
- Log structured quarterly check-in comments per employee
- View Planned vs. Actual comparison for each team member
- Access team heatmap, QoQ analytics, and AI risk alerts
- Export team achievement reports

**Cannot do:**
- Create goals on behalf of employees
- Unlock goals post-approval (Admin only)
- Access other teams' data

---

### 🔴 Admin / HR
The governance authority with full organisational oversight.

**Can do:**
- Configure and activate goal-setting cycles and quarter windows
- Manage user accounts, roles, and reporting line assignments
- View all goal sheets and check-in data org-wide
- Unlock individual goal items post-approval (with mandatory reason + automatic audit log)
- Push shared KPIs at any scope (team, department, or entire org)
- View, filter, and export the complete audit trail
- Access Manager Effectiveness leaderboard and org-wide analytics
- Generate and download achievement reports for any scope and period

---

## 🛠️ Tech Stack

| Layer | Technology | Reason |
|---|---|---|
| **Frontend** | Flutter Web (Dart) | Single codebase, strong widget system, excellent animation support |
| **Backend** | FastAPI (Python 3.11) | Extremely fast to develop, async-native, auto OpenAPI docs |
| **Database** | Firebase Firestore | Real-time listeners, serverless scaling, offline support |
| **Authentication** | Firebase Auth | Email/password + custom claims for role-based access |
| **AI / LLM** | Google Gemini 1.5 Flash | Speed + cost efficiency; structured JSON output for parsing |
| **Charts** | fl_chart (Flutter) | Rich chart types: line, bar, doughnut, custom heatmap |
| **State Management** | Flutter Riverpod | Reactive, testable, excellent async data handling |
| **Routing** | go_router | Type-safe, role-guarded routing with deep link support |
| **HTTP Client** | Dio | Interceptors for auth token injection on every request |
| **Report Export** | pandas + openpyxl | CSV and Excel generation server-side |
| **Notifications** | Firestore Streams + SendGrid | Real-time in-app; email for production |
| **Deployment** | Firebase Hosting + Railway | Zero-config CDN for Flutter; one-click Python on Railway |

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER'S BROWSER                           │
│              Flutter Web SPA (go_router + Riverpod)             │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPS + Bearer Token (Dio)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                  FIREBASE HOSTING (CDN)                         │
│              Serves Flutter Web compiled assets                 │
└─────────────────────────────────────────────────────────────────┘
                           │ REST API calls
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│              FASTAPI BACKEND (Railway / Render)                 │
│                                                                 │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐  │
│  │ Auth       │  │ Goals      │  │ Check-ins  │  │ Admin    │  │
│  │ Router     │  │ Router     │  │ Router     │  │ Router   │  │
│  └────────────┘  └────────────┘  └────────────┘  └──────────┘  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌──────────┐  │
│  │ Shared     │  │ Analytics  │  │ AI         │  │ Reports  │  │
│  │ Goals      │  │ Router     │  │ Router     │  │ Service  │  │
│  └────────────┘  └────────────┘  └────────────┘  └──────────┘  │
│                                                                 │
│  ┌──────────────────────┐    ┌──────────────────────────────┐   │
│  │  firebase-admin SDK  │    │  google-generativeai SDK     │   │
│  └──────────┬───────────┘    └──────────────┬───────────────┘   │
└─────────────┼──────────────────────────────-┼───────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────────┐
│   FIREBASE FIRESTORE    │     │    GOOGLE GEMINI 1.5 FLASH   │
│                         │     │                             │
│  users · goals          │     │  Goal suggestions           │
│  checkins · cycles      │     │  Quarterly summaries        │
│  shared_goals           │     │  Risk recommendations       │
│  audit_logs             │     │  KPI hints                  │
│  notifications          │     │                             │
│  escalation_rules       │     └─────────────────────────────┘
└─────────────────────────┘
              │
              │ Real-time streams (Firestore SDK)
              ▼
     Flutter StreamProviders
     (Notifications, Goal Sheet Status)
```

### Data Flow: Employee Goal Submission → Manager Approval

```
Employee fills Goal Builder
        │
        ▼
[Validation Engine]
  • ≤ 8 goals ✓
  • Each ≥ 10% ✓
  • Sum = 100% ✓
        │
        ▼
POST /goals/{id}/submit
        │
        ▼
FastAPI → Firestore: sheetStatus = "submitted"
        │
        ▼
NotificationService → writes notification doc
        │
        ▼
Manager's bell badge updates (Firestore real-time stream)
        │
        ▼
Manager reviews → PUT /goals/{id}/approve
        │
        ▼
FastAPI → Firestore batch:
  • All goals[i].isLocked = true
  • sheetStatus = "locked"
  • audit_log entry created
  • employee notification written
        │
        ▼
Employee dashboard updates (Firestore real-time stream)
```

---

## 🚀 Getting Started

### Prerequisites

| Requirement | Version |
|---|---|
| Flutter SDK | ≥ 3.16.0 |
| Dart | ≥ 3.2.0 |
| Python | ≥ 3.11 |
| Firebase CLI | Latest |
| Google Cloud Project | With Firestore + Auth enabled |
| Gemini API Key | From Google AI Studio |

---

## 🔧 Environment Variables

### Backend (`goalpulse_backend/.env`)

```env
# Firebase
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_SERVICE_ACCOUNT_JSON=base64-encoded-service-account-json

# AI
GEMINI_API_KEY=your-gemini-api-key-from-google-ai-studio

# Email (optional — stubs work without this)
SENDGRID_API_KEY=your-sendgrid-api-key

# App
FRONTEND_URL=https://your-flutter-app.web.app
ENVIRONMENT=development
```

> **How to encode your service account JSON:**
> ```bash
> base64 -i service-account.json | tr -d '\n'
> ```
> Paste the output as the value of `FIREBASE_SERVICE_ACCOUNT_JSON`.

### Frontend (`goalpulse_frontend/lib/core/config.dart`)

```dart
// Set at build time via --dart-define
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/v1',
  );
}
```

---

## 💻 Running Locally

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/goalpulse.git
cd goalpulse
```

### 2. Set Up Firebase

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and initialise
firebase login
firebase use --add   # select your project
```

Enable **Firestore**, **Firebase Authentication**, and **Firebase Hosting** in your Firebase Console.

Deploy Firestore security rules:
```bash
firebase deploy --only firestore:rules
```

### 3. Start the Backend

```bash
cd goalpulse_backend

# Create virtual environment
python -m venv venv
source venv/bin/activate    # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# → Edit .env with your Firebase and Gemini credentials

# Seed demo data (run once)
python seed_demo_data.py

# Start the API server
uvicorn main:app --reload --port 8000
```

API docs available at: `http://localhost:8000/docs`

### 4. Start the Frontend

```bash
cd goalpulse_frontend

# Install Flutter dependencies
flutter pub get

# Run on Chrome (development)
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000/v1
```

The app will open at `http://localhost:XXXX` in your browser.

### 5. Verify Everything Works

```bash
# Backend health check
curl http://localhost:8000/health
# Expected: {"status": "ok", "version": "1.0.0"}

# Login with demo account
# admin@demo.com / Demo@1234 → should route to Admin Dashboard
```

---

## 🌐 Deployment

### Frontend → Firebase Hosting

```bash
cd goalpulse_frontend

# Build for production
flutter build web --release \
  --dart-define=API_BASE_URL=https://your-api.railway.app/v1

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Backend → Railway

1. Push `goalpulse_backend/` to a GitHub repository.
2. Create a new project on [Railway](https://railway.app).
3. Connect your GitHub repository.
4. Add all environment variables from `.env` in Railway's Variable settings.
5. Railway detects the `Dockerfile` and deploys automatically.
6. Your API will be live at `https://your-project.railway.app`.

### Firestore Indexes

Create these composite indexes in the Firebase Console → Firestore → Indexes:

```
Collection: goals
  Fields: employeeId ASC, cycleId ASC

Collection: goals
  Fields: managerId ASC, sheetStatus ASC

Collection: checkins
  Fields: goalId ASC, quarter ASC

Collection: notifications
  Fields: recipientId ASC, createdAt DESC

Collection: audit_logs
  Fields: timestamp DESC, actorId ASC
```

---

## 📡 API Documentation

Full interactive API docs: `https://your-api.railway.app/docs`

### Core Endpoints

| Method | Endpoint | Role | Description |
|---|---|---|---|
| `POST` | `/auth/verify` | All | Verify Firebase token, return user profile |
| `GET` | `/goals/my` | Employee | Fetch own goal sheet for active cycle |
| `POST` | `/goals` | Employee | Create new goal sheet (draft) |
| `PUT` | `/goals/{id}` | Employee | Update goal sheet |
| `POST` | `/goals/{id}/submit` | Employee | Submit for Manager approval |
| `GET` | `/goals/team` | Manager | Fetch team's goal sheets |
| `PUT` | `/goals/{id}/approve` | Manager | Approve + lock goal sheet |
| `PUT` | `/goals/{id}/return` | Manager | Return with mandatory comment |
| `POST` | `/goals/{id}/unlock-item` | Admin | Unlock a specific goal item |
| `POST` | `/checkins` | Employee | Submit quarterly actuals |
| `GET` | `/checkins/{goalId}` | All | Fetch check-in records |
| `PUT` | `/checkins/{id}/manager-review` | Manager | Add check-in comment |
| `POST` | `/checkins/{id}/ai-summary` | Employee/Manager | Generate AI summary |
| `POST` | `/shared-goals` | Manager/Admin | Push shared KPI to employees |
| `GET` | `/analytics/completion-dashboard` | Manager/Admin | Check-in completion rates |
| `GET` | `/analytics/qoq-trends` | Manager/Admin | Quarter-on-quarter scores |
| `GET` | `/analytics/manager-effectiveness` | Admin | Manager performance metrics |
| `POST` | `/ai/suggest-goals` | Employee | Get AI goal suggestions |
| `POST` | `/ai/risk-prediction` | Manager | Get AI risk prediction for team |
| `POST` | `/ai/kpi-recommendations` | Employee | Get KPI recommendation for a goal |
| `GET` | `/admin/users` | Admin | List and search all users |
| `GET` | `/admin/audit-logs` | Admin | Paginated, filterable audit trail |
| `GET` | `/admin/reports/achievement` | Manager/Admin | Download achievement report |

All endpoints require `Authorization: Bearer {firebase_id_token}` header.

---

## 🗄️ Database Schema

GoalPulse uses 8 Firestore collections:

```
📁 users/
   └── {userId}: id, email, displayName, role, managerId,
                 department, designation, isActive

📁 goals/
   └── {goalId}: employeeId, managerId, cycleId, sheetStatus,
                 goals[] → GoalItem{
                   goalItemId, thrustArea, title, description,
                   uomType, target, weightage,
                   isShared, sharedGoalId, isLocked,
                   quarterlyData{Q1,Q2,Q3,Q4}
                 },
                 totalWeightage, submittedAt, approvedAt,
                 approvedBy, managerComment

📁 checkins/
   └── {checkinId}: goalId, employeeId, managerId, quarter,
                    status, managerComment, aiSummary,
                    actuals[]{goalItemId, actual, status, progressScore},
                    employeeSubmittedAt, managerReviewedAt

📁 shared_goals/
   └── {id}: createdBy, cycleId, thrustArea, title, description,
              uomType, target, suggestedWeightage,
              recipientIds[], ownerEmployeeId,
              linkedGoalItemIds{userId → goalItemId}

📁 audit_logs/
   └── {logId}: actorId, actorRole, targetType, targetId,
                employeeId, action, fieldChanged,
                oldValue, newValue, reason, timestamp

📁 notifications/
   └── {id}: recipientId, type, title, body,
              relatedEntityType, relatedEntityId,
              isRead, createdAt

📁 cycles/
   └── {cycleId}: year, isActive,
                  phases{goalSetting, Q1, Q2, Q3, Q4}
                  → each: {openDate, closeDate}

📁 escalation_rules/
   └── {ruleId}: name, trigger, triggerDelayDays,
                 notifyRoles[], messageTemplate, isActive
```

---

## ✅ Validation Rules

These rules are enforced simultaneously in the **Flutter frontend** (real-time UI) and the **FastAPI backend** (authoritative server-side check):

| Rule | Constraint | Error Response |
|---|---|---|
| Goal Count | 1 – 8 goals per sheet | 422: "Maximum 8 goals allowed" |
| Min Weightage | Each goal ≥ 10% | 422: "Goal weightage must be at least 10%" |
| Total Weightage | Sum = 100% (±0.01 tolerance) | 422: "Total weightage must equal 100%" |
| Required Fields | thrustArea, title, uomType, target | 422: field-specific message |
| Submission State | Must be draft or returned | 403: "Goal sheet is not in editable state" |
| Check-in Window | Must be within open quarter window | 403: "Check-in window is not currently open" |
| Goal Lock | Cannot edit locked goal items | 403: "Goal is locked. Contact Admin to unlock." |
| Return Comment | Mandatory non-empty string | 422: "Comment is required when returning a goal" |
| Unlock Reason | Mandatory non-empty string | 422: "A reason is required to unlock a goal" |
| Shared Goal Fields | Recipients cannot edit title/desc/target | 403: "Shared goal fields cannot be modified" |

---

## 🤖 AI Features Deep Dive

### Goal Suggestion Assistant

**Trigger:** Employee taps "✨ AI Suggest" on any goal card.

**Prompt strategy:** Role + department + thrust area + existing titles (to avoid duplicates) → Gemini returns 3 structured SMART goal suggestions as JSON.

**Fallback:** If Gemini is unavailable, returns pre-seeded suggestions from a local dictionary indexed by thrust area.

**UI:** Slide-over drawer with loading animation → 3 suggestion cards → one-tap "Use This Goal" fills all fields.

---

### Quarterly Summary Generator

**Trigger:** Employee or Manager clicks "Generate AI Summary" after check-in submission.

**Prompt strategy:** All goal actuals with UoM context + computed progress scores + Manager's check-in comment → Gemini returns a professional 4–5 sentence performance narrative.

**Output quality guardrails in prompt:** "Do not use generic phrases like 'continued to demonstrate' or 'showed dedication'. Start with the strongest achievement. End with a forward-looking recommendation."

**Storage:** Summary saved to `checkins/{id}.aiSummary` — visible in progress history and exportable in reports.

---

### Goal Risk Prediction

**Trigger:** Runs automatically after Q1/Q2 check-in submissions across the team.

**Computation:** Python-based trajectory analysis first (no unnecessary Gemini calls):
- `numeric_min/percent_min`: project annual = `(Q1_actual / target) × 4`
- Risk classification: Low ≥ 90% projected, Medium 60–89%, High < 60%

**Gemini involvement:** Only for High and Medium risk items — generates one-sentence actionable recommendations to save API quota.

**UI:** Manager Dashboard "AI Risk Alerts" panel with colour-coded badges and collapsible recommendations per goal.

---

### Smart KPI Recommendations

**Trigger:** Debounced 500ms after employee types in Goal Title field (only fires if Thrust Area also selected).

**Prompt strategy:** Role + thrust area + partial goal title → Gemini recommends UoM type + ballpark target value + one-line rationale.

**UI:** Non-intrusive inline hint below UoM and Target fields. "Apply" button fills both fields. "Dismiss" hides the hint.

---

## 📁 Project Structure

```
goalpulse/
├── goalpulse_frontend/             # Flutter Web Application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── theme/              # Colors, typography, ThemeData
│   │   │   ├── router/             # go_router with role guards
│   │   │   ├── services/           # Auth, API, Notifications
│   │   │   ├── utils/              # Validators, Progress Calculator
│   │   │   └── config.dart         # API base URL, app constants
│   │   ├── features/
│   │   │   ├── auth/               # Login, Forgot Password
│   │   │   ├── employee/           # Dashboard, Goals, Check-ins, Progress
│   │   │   ├── manager/            # Dashboard, Approvals, Check-ins, Analytics
│   │   │   ├── admin/              # Dashboard, Users, Cycles, Audit, Reports
│   │   │   └── shared/             # Notifications panel
│   │   ├── models/                 # Dart data models (fromJson/toJson)
│   │   └── widgets/                # Reusable: KpiCard, StatusBadge,
│   │       ├── chart_widgets/      #   Charts: Line, Bar, Doughnut, Heatmap
│   │       ├── loading_skeleton.dart
│   │       ├── empty_state_widget.dart
│   │       └── confirm_dialog.dart
│   ├── assets/
│   │   └── images/empty_states/    # SVG illustrations
│   ├── web/                        # Flutter web bootstrap files
│   └── pubspec.yaml
│
└── goalpulse_backend/              # FastAPI Application
    ├── main.py                     # App entry, CORS, router registration
    ├── config.py                   # Pydantic settings from .env
    ├── seed_demo_data.py           # One-time demo data seeder
    ├── Dockerfile                  # Railway deployment
    ├── requirements.txt
    ├── .env.example
    └── app/
        ├── routers/                # auth, goals, checkins, shared_goals,
        │                           # analytics, admin, ai
        ├── models/                 # Pydantic request/response models
        ├── services/               # Business logic:
        │   ├── firebase_service.py #   Firestore client, Admin SDK
        │   ├── auth_service.py     #   Token verification
        │   ├── goal_service.py     #   Goal CRUD + approval + locking
        │   ├── checkin_service.py  #   Actuals + progress scores
        │   ├── shared_goal_service.py # Push + sync logic
        │   ├── analytics_service.py   # Aggregation queries
        │   ├── ai_service.py       #   Gemini prompt orchestration
        │   ├── report_service.py   #   CSV/Excel generation
        │   └── notification_service.py
        ├── middleware/
        │   ├── auth_middleware.py  # Token verify + role inject
        │   └── audit_middleware.py # Auto audit log for write ops
        ├── utils/
        │   ├── progress_calculator.py  # UoM score formulas
        │   └── validators.py       # Goal validation logic
        └── jobs/
            ├── escalation_job.py   # APScheduler daily check
            └── risk_prediction_job.py
```

---

## 🗺️ Roadmap

### v1.0 — Hackathon Release (Current)
- [x] Core goal creation, validation, and approval workflow
- [x] Quarterly check-in with 6 UoM score types
- [x] Shared goals with atomic sync
- [x] AI goal suggestions, summaries, risk prediction, KPI hints
- [x] Analytics dashboards with heatmaps and QoQ trends
- [x] Audit trail and admin governance panel
- [x] CSV + Excel report export

### v1.1 — Post-Hackathon
- [ ] Microsoft Entra ID / Azure AD SSO integration with org hierarchy auto-sync
- [ ] Microsoft Teams Adaptive Card notifications (deep links into goal sheets)
- [ ] Email notifications via SendGrid (full templates, not stubs)
- [ ] PDF export of individual goal sheets (formatted, printable)
- [ ] Goal template library by role and department

### v2.0 — Enterprise Scale
- [ ] Multi-cycle historical comparison (cross-year analytics)
- [ ] 360-degree feedback module integration
- [ ] OKR framework support alongside KPI-based goals
- [ ] Multi-tenant organisational hierarchy (matrix reporting)
- [ ] Advanced AI: natural language goal refinement, benchmark comparisons
- [ ] Mobile apps (iOS + Android — Flutter single codebase)
- [ ] SCIM-based directory sync for large enterprises


## 📄 License

This project was built for hackathon purposes. All rights reserved by the team.

---

<div align="center">

**GoalPulse** — *Align. Track. Achieve.*

Built with Flutter · FastAPI · Firebase · Gemini AI

</div>
