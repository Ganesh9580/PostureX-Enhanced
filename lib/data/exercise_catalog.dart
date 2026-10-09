import '../models/exercise.dart';
import '../services/calibration_manager.dart';

/// Central repository providing structured metadata for all exercises in PostureX.
class ExerciseCatalog {
  static const List<Exercise> allExercises = [
    // --- Upper Body ---
    Exercise(
      id: "pushup",
      name: "Push-ups",
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.intermediate,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Chest", "Triceps", "Anterior Deltoids", "Core"],
      description: "Classic bodyweight push-up measuring elbow depth and body line straightness.",
      instructions: [
        "Place hands shoulder-width apart on the floor.",
        "Maintain a straight line from head to heels without sagging hips.",
        "Lower chest toward the floor until elbows bend to ~90°.",
        "Push firmly back up to full extension."
      ],
      cameraSetupGuide: "Position device on the floor or a low surface 2m away, showing a side-on view of your entire body in plank.",
      isPremium: false,
      defaultGoal: 5,
      exerciseType: ExerciseType.pushup,
    ),
    Exercise(
      id: "biceps_curl",
      name: "Biceps Curls",
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraPosition: CameraPosition.frontView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Biceps Brachii", "Brachialis", "Forearms"],
      description: "Arm flexion movement tracking elbow angle contraction and torso stability.",
      instructions: [
        "Stand tall facing the camera with arms fully extended by your sides.",
        "Keep elbows pinned close to your ribcage.",
        "Curl wrists upward toward shoulders until biceps fully contract.",
        "Slowly lower back down with controlled form."
      ],
      cameraSetupGuide: "Place device at chest height 2m in front of you, ensuring full upper body is visible.",
      isPremium: false,
      defaultGoal: 10,
      exerciseType: ExerciseType.bicepsCurl,
    ),
    Exercise(
      id: "shoulder_press",
      name: "Shoulder Press",
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.intermediate,
      cameraPosition: CameraPosition.frontView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Overhead Deltoids", "Upper Chest", "Triceps"],
      description: "Overhead pushing movement analyzing wrist height relative to shoulders.",
      instructions: [
        "Stand straight with hands positioned near shoulder height.",
        "Press hands directly overhead until arms are nearly fully extended.",
        "Pause briefly at peak extension.",
        "Lower hands under control back to shoulder height."
      ],
      cameraSetupGuide: "Place device at chest height 2m away, ensuring your head and full overhead arm reach are in frame.",
      isPremium: true,
      defaultGoal: 10,
      exerciseType: ExerciseType.shoulderPress,
    ),
    Exercise(
      id: "lateral_raise",
      name: "Lateral Raises",
      category: ExerciseCategory.upperBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraPosition: CameraPosition.frontView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Lateral Deltoids", "Trapezius"],
      description: "Side shoulder abduction measuring arm elevation to shoulder height.",
      instructions: [
        "Stand straight with arms at your sides facing the camera.",
        "Raise arms sideways until parallel with the floor (T-pose).",
        "Keep a slight bend in elbows and avoid swinging torso.",
        "Lower arms back down smoothly."
      ],
      cameraSetupGuide: "Position device 2m directly in front of you so both arms can spread laterally without leaving the frame.",
      isPremium: false,
      defaultGoal: 10,
      exerciseType: ExerciseType.lateralRaise,
    ),

    // --- Lower Body ---
    Exercise(
      id: "squat",
      name: "Squats",
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Quadriceps", "Glutes", "Hamstrings", "Lower Back"],
      description: "Fundamental compound movement measuring knee flexion depth and back angle.",
      instructions: [
        "Stand with feet shoulder-width apart, toes slightly turned out.",
        "Push hips back and bend knees as if sitting into a chair.",
        "Lower until thighs are parallel with the floor (~90° knee angle).",
        "Keep chest upright and drive through heels to stand."
      ],
      cameraSetupGuide: "Position device 2m away on a stable surface showing a clear side-on view of your hips and knees.",
      isPremium: false,
      defaultGoal: 10,
      exerciseType: ExerciseType.squat,
    ),
    Exercise(
      id: "lunge",
      name: "Lunges",
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.intermediate,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Quadriceps", "Glutes", "Calves", "Core"],
      description: "Unilateral leg movement analyzing lead knee flex and trunk posture.",
      instructions: [
        "Step forward with one leg, lowering hips until both knees form ~90° angles.",
        "Keep front knee stacked directly above ankle.",
        "Keep torso upright and back straight.",
        "Push off front foot to return to standing."
      ],
      cameraSetupGuide: "Set up camera 2m to your side so both front and rear leg angles are clearly captured.",
      isPremium: false,
      defaultGoal: 10,
      exerciseType: ExerciseType.lunge,
    ),
    Exercise(
      id: "calf_raise",
      name: "Calf Raises",
      category: ExerciseCategory.lowerBody,
      difficulty: ExerciseDifficulty.beginner,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Gastrocnemius", "Soleus"],
      description: "Ankle plantarflexion movement tracking heel elevation.",
      instructions: [
        "Stand upright with feet hip-width apart.",
        "Push up onto the balls of your feet, raising heels as high as possible.",
        "Pause at the top peak contraction.",
        "Lower heels slowly back to the floor."
      ],
      cameraSetupGuide: "Place camera 2m to your side or front showing feet and ankles clearly.",
      isPremium: false,
      defaultGoal: 15,
      exerciseType: ExerciseType.calfRaise,
    ),

    // --- Core ---
    Exercise(
      id: "plank",
      name: "Plank",
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.intermediate,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.staticHold,
      targetMuscles: ["Rectus Abdominis", "Transverse Abdominis", "Obliques"],
      description: "Isometric core hold measuring body line alignment and hip stability.",
      instructions: [
        "Place forearms on the floor with elbows under shoulders.",
        "Extend legs straight behind you, resting on toes.",
        "Engage core to maintain a straight line from shoulders to ankles.",
        "Avoid letting hips sag down or arch upward."
      ],
      cameraSetupGuide: "Place device on the floor 2m to your side showing full head-to-toe alignment.",
      isPremium: false,
      defaultGoal: 20,
      exerciseType: ExerciseType.plank,
    ),
    Exercise(
      id: "side_plank",
      name: "Side Plank",
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.intermediate,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.staticHold,
      targetMuscles: ["Obliques", "Gluteus Medius", "Core Stabilizers"],
      description: "Lateral isometric hold measuring side body alignment.",
      instructions: [
        "Lie on your side supported by one elbow directly under shoulder.",
        "Stack feet and lift hips off the ground into a diagonal straight line.",
        "Extend top arm upward or rest hand on hip.",
        "Hold position without letting hips drop."
      ],
      cameraSetupGuide: "Set up camera 2m in front showing full side body profile.",
      isPremium: true,
      defaultGoal: 15,
      exerciseType: ExerciseType.sidePlank,
    ),
    Exercise(
      id: "standing_knee_raises",
      name: "Standing Knee Raises",
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.beginner,
      cameraPosition: CameraPosition.frontView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Hip Flexors", "Lower Abs", "Balance"],
      description: "Standing hip flexion movement tracking knee height relative to waist.",
      instructions: [
        "Stand tall facing the camera.",
        "Drive one knee up toward chest height until hip flexes to 90°+.",
        "Lower leg back down with control and alternate sides.",
        "Keep torso tall without leaning backward."
      ],
      cameraSetupGuide: "Place camera at waist height 2m directly in front.",
      isPremium: false,
      defaultGoal: 12,
      exerciseType: ExerciseType.standingKneeRaises,
    ),

    // --- Full Body & Cardio ---
    Exercise(
      id: "jumping_jack",
      name: "Jumping Jacks",
      category: ExerciseCategory.fullBodyCardio,
      difficulty: ExerciseDifficulty.beginner,
      cameraPosition: CameraPosition.frontView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Full Body", "Calves", "Deltoids", "Cardiovascular"],
      description: "Dynamic plyometric exercise tracking arm raise and leg spread cycles.",
      instructions: [
        "Start standing with feet together and arms at your sides.",
        "Jump feet outward past hip width while sweeping arms overhead.",
        "Jump back to starting closed position.",
        "Maintain a continuous, rhythmic pace."
      ],
      cameraSetupGuide: "Position device 2.5m in front of you so arms overhead and wide leg stance stay in frame.",
      isPremium: true,
      defaultGoal: 10,
      exerciseType: ExerciseType.jumpingJack,
    ),
    Exercise(
      id: "jump_squat",
      name: "Jump Squats",
      category: ExerciseCategory.fullBodyCardio,
      difficulty: ExerciseDifficulty.advanced,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Quadriceps", "Glutes", "Calves", "Explosive Power"],
      description: "High-intensity squat variation combining deep flex with vertical jump elevation.",
      instructions: [
        "Perform a full squat until thighs are parallel to the ground.",
        "Explode upward off the floor extending hips, knees, and ankles.",
        "Land softly absorbing impact straight into the next squat descent."
      ],
      cameraSetupGuide: "Set up camera 2m to your side ensuring head is not cut off during jump peak.",
      isPremium: true,
      defaultGoal: 10,
      exerciseType: ExerciseType.jumpSquat,
    ),
    Exercise(
      id: "high_knees",
      name: "High Knees",
      category: ExerciseCategory.fullBodyCardio,
      difficulty: ExerciseDifficulty.intermediate,
      cameraPosition: CameraPosition.frontView,
      analysisType: AnalysisType.repetition,
      targetMuscles: ["Hip Flexors", "Quads", "Cardio System"],
      description: "Fast-paced running in place driving knees up toward chest.",
      instructions: [
        "Run in place driving knees high toward hip level.",
        "Pump opposite arms in rhythm.",
        "Stay light on balls of your feet."
      ],
      cameraSetupGuide: "Place camera 2m in front showing full upper and lower body.",
      isPremium: false,
      defaultGoal: 20,
      exerciseType: ExerciseType.highKnees,
    ),

    // --- Mobility & Yoga ---
    Exercise(
      id: "tree_pose",
      name: "Tree Pose (Vrksasana)",
      category: ExerciseCategory.mobilityYoga,
      difficulty: ExerciseDifficulty.beginner,
      cameraPosition: CameraPosition.frontView,
      analysisType: AnalysisType.staticHold,
      targetMuscles: ["Ankle Stability", "Core", "Hips", "Balance"],
      description: "Standing balance pose tracking single-leg stability and posture alignment.",
      instructions: [
        "Shift weight onto one standing leg.",
        "Place sole of opposite foot against inner calf or thigh (avoid knee joint).",
        "Bring palms together at chest center or extend arms overhead.",
        "Hold balance while breathing deeply."
      ],
      cameraSetupGuide: "Position camera 2m directly in front showing full body from feet to overhead hands.",
      isPremium: false,
      defaultGoal: 15,
      exerciseType: ExerciseType.treePose,
    ),
    Exercise(
      id: "warrior_two",
      name: "Warrior II (Virabhadrasana II)",
      category: ExerciseCategory.mobilityYoga,
      difficulty: ExerciseDifficulty.intermediate,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.staticHold,
      targetMuscles: ["Hips", "Groin", "Shoulders", "Leg Endurance"],
      description: "Standing yoga pose measuring lead knee flex and horizontal arm alignment.",
      instructions: [
        "Step feet wide apart (~1m). Turn front foot out 90° and back foot slightly in.",
        "Bend front knee to 90° stacked directly over ankle.",
        "Extend arms horizontally parallel to the floor, gazing over front fingertips.",
        "Keep torso upright centered between hips."
      ],
      cameraSetupGuide: "Set up camera 2m away facing your side body profile.",
      isPremium: true,
      defaultGoal: 15,
      exerciseType: ExerciseType.warriorTwo,
    ),
    Exercise(
      id: "chair_pose",
      name: "Chair Pose (Utkatasana)",
      category: ExerciseCategory.mobilityYoga,
      difficulty: ExerciseDifficulty.intermediate,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.staticHold,
      targetMuscles: ["Quadriceps", "Glutes", "Shoulder Mobility", "Spine"],
      description: "Isometric squat hold with arms extended overhead.",
      instructions: [
        "Stand with feet together or hip-width apart.",
        "Bend knees and sink hips down as if sitting in an imaginary chair.",
        "Raise arms overhead in line with ears.",
        "Keep spine long and hold position steady."
      ],
      cameraSetupGuide: "Place camera 2m to your side capturing knee angle and arm alignment.",
      isPremium: false,
      defaultGoal: 15,
      exerciseType: ExerciseType.chairPose,
    ),
    Exercise(
      id: "forward_bend",
      name: "Standing Forward Bend",
      category: ExerciseCategory.mobilityYoga,
      difficulty: ExerciseDifficulty.beginner,
      cameraPosition: CameraPosition.sideView,
      analysisType: AnalysisType.staticHold,
      targetMuscles: ["Hamstrings", "Calves", "Spinal Flexibility"],
      description: "Flexibility stretch measuring hip hinge fold angle.",
      instructions: [
        "Stand tall with feet hip-width apart.",
        "Hinge at hips to fold torso forward over legs.",
        "Reach hands toward floor or shins, relaxing neck and head.",
        "Hold stretch comfortably without forcing depth."
      ],
      cameraSetupGuide: "Position camera 2m to your side to measure hip fold angle.",
      isPremium: false,
      defaultGoal: 15,
      exerciseType: ExerciseType.forwardBend,
    ),
  ];

  static List<Exercise> getByCategory(ExerciseCategory category) {
    return allExercises.where((e) => e.category == category).toList();
  }

  static Exercise? getById(String id) {
    try {
      return allExercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static Exercise getByExerciseType(ExerciseType type) {
    return allExercises.firstWhere(
      (e) => e.exerciseType == type,
      orElse: () => allExercises.first,
    );
  }
}
