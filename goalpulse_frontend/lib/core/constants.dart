/// Domain enumerations and constant lists used across GoalPulse.

// ── Roles ────────────────────────────────────────────────────────────────
enum UserRole { employee, manager, admin }

// ── Goal‑sheet lifecycle ─────────────────────────────────────────────────
enum GoalSheetStatus { draft, submitted, approved, returned, locked }

// ── Unit of Measure types ────────────────────────────────────────────────
enum UomType { numericMin, numericMax, percentMin, percentMax, timeline, zero }

// ── Individual goal status ───────────────────────────────────────────────
enum GoalStatus { notStarted, onTrack, completed }

// ── Financial quarters ───────────────────────────────────────────────────
// ignore: constant_identifier_names
enum Quarter { Q1, Q2, Q3, Q4 }

// ── Check‑in review status ──────────────────────────────────────────────
enum CheckinStatus { pending, actualsSubmitted, managerReviewed }

// ── Strategic thrust areas ──────────────────────────────────────────────
const List<String> thrustAreas = [
  'Revenue Growth',
  'Cost Optimisation',
  'Customer Experience',
  'Operational Excellence',
  'People & Culture',
  'Digital Transformation',
  'Quality & Compliance',
  'Innovation',
];
