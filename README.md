# PostureX — Your AI Movement Coach

**PostureX** is a local-first, privacy-focused mobile AI fitness application built with Flutter/Dart and Google ML Kit Pose Detection. It provides real-time movement analysis, repetition counting, hold timing, posture calibration, and voice coaching feedback directly on-device.

---

## 🌟 Key Features

1. **Real-Time On-Device Pose Analysis**:
   - Live pose tracking using Google ML Kit Pose Detection.
   - Vector-based 3-point joint angle math with dot-product safety, cosine clamping, and moving-average smoothing.
   - Landmark visibility guard (`PoseVisibilityChecker`) and static pose balance stability tracker (`PoseStabilityTracker`).
2. **Comprehensive Exercise Library**:
   - 23 structured exercises across 5 categories: **Upper Body**, **Lower Body**, **Core**, **Full Body & Cardio**, and **Mobility & Yoga**.
   - Search & category filtering with target muscle group indicators and camera positioning guides.
3. **Personalized User Profile & Dashboard**:
   - Profile management (name, age, height, weight, experience level, fitness goals, and measurement units).
   - Real-time dashboard analytics: total sessions, total reps, hold time, reward points, weekly activity bar chart, and Personal Record (PR) badges.
4. **Custom Workout Routines & Guided Player**:
   - Built-in preloaded routines and custom routine builder (sets, reps, hold durations, rest intervals).
   - Guided workout execution player with interactive rest countdown timers and exercise transitions.
5. **Local-First & Privacy Preserving**:
   - 100% on-device SQLite database (`posture_coach.db` v3).
   - No cloud account, authentication, or external frame uploads required.

---

## 🏗️ Technical Architecture

- **Framework**: Flutter 3.12+ (Material 3 Dark Theme)
- **State & Storage**: SQLite (`sqflite`), pure Dart service layer (`DatabaseService`, `ProfileService`, `RoutineService`, `PointsService`)
- **Machine Learning**: `google_mlkit_pose_detection` (Live camera stream format `ImageFormatGroup.nv21`)
- **Audio Feedback**: `flutter_tts` (Rate-limited, priority-interrupted text-to-speech cues)

```
lib/
├── data/
│   └── exercise_catalog.dart         # 23 structured exercise definitions
├── models/
│   ├── exercise.dart                 # Exercise metadata & category models
│   ├── personal_record.dart          # Personal best result tracking
│   ├── user_profile.dart             # Demographics, goals & units preferences
│   └── workout_routine.dart          # Workout routine & item models
├── screens/
│   ├── dashboard_screen.dart         # Analytics dashboard & PR badges
│   ├── exercise_detail_screen.dart   # Camera setup guide & exercise overview
│   ├── exercise_library_screen.dart  # Searchable exercise list & category filters
│   ├── home_screen.dart              # Main 4-tab bottom navigation controller
│   ├── profile_screen.dart           # Profile editor & completion meter
│   ├── routine_editor_screen.dart    # Custom routine builder
│   ├── routine_list_screen.dart      # Routine library & recommendations
│   ├── routine_player_screen.dart    # Guided workout player & rest timers
│   ├── session_summary_screen.dart   # Post-workout breakdown & points awards
│   └── tracking_screen.dart          # Live camera ML Kit pose detector & HUD
├── services/
│   ├── angle_calculator.dart         # Joint angle math & smoothing
│   ├── calibration_manager.dart      # Start-pose shadow guide alignment
│   ├── database_service.dart         # SQLite v1->v2->v3 migration & queries
│   ├── form_scorer.dart              # 0-10 form quality scoring algorithms
│   ├── hold_timer.dart               # Static hold continuous timer
│   ├── jumping_jack_detector.dart    # Open/closed cycle detector
│   ├── movement_analyzer.dart        # Exercise-specific joint angle dispatcher
│   ├── points_service.dart           # Reward points & unlock thresholds
│   ├── pose_stability_tracker.dart   # Frame variance balance stability
│   ├── pose_visibility_checker.dart  # Landmark likelihood & camera framing guard
│   ├── profile_service.dart          # Goal guidance & profile CRUD helper
│   ├── rep_detector.dart             # Up/Down debounced rep state machine
│   ├── routine_service.dart          # Routine recommendations & storage
│   └── voice_feedback_service.dart   # Rate-limited TTS wrapper
└── theme/
    └── app_theme.dart                # Centralized dark design system
```

---

## 🛠️ Getting Started & Local Setup

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.12+)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator running Android 7.0+ (API level 24+) with camera capabilities

### Installation & Execution

1. Clone or navigate to the project directory:
   ```bash
   cd ai_posture_coach
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run static code analysis:
   ```bash
   flutter analyze --no-pub
   ```

4. Run unit test suite:
   ```bash
   flutter test --no-pub
   ```

5. Launch on a connected Android device:
   ```bash
   flutter run
   ```

---

## 🔒 Privacy & Data Policy

- All camera frame processing occurs **strictly on-device**. No images, video recordings, or telemetry leave your device.
- All workout statistics, user profiles, and session histories are stored locally in the app's SQLite database.
