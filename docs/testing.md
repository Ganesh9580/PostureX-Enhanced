# PostureX — Testing Documentation

## 1. Overview

PostureX uses Flutter's testing framework to verify application behavior. The project includes automated tests for database operations and other application components.

The test files are located in the `test/` directory.

## 2. Running Tests

Run the complete test suite from the project root:

```bash
flutter test
```

Run static analysis to identify potential code issues:

```bash
flutter analyze
```

## 3. Database Test Coverage

The database tests are defined in `test/database_service_test.dart`.

The implemented test suite covers:

- Default application points.
- Accumulation of reward points.
- Saving and retrieving workout sessions.
- Personal-record handling.
- Dashboard statistics aggregation.

These tests help verify that database operations behave as expected.

## 4. Previously Verified Results

During the current development cycle, the following checks completed successfully:

| Check | Result |
|---|---|
| Flutter static analysis | No issues found |
| Automated Flutter tests | 21 tests passed |
| Android release build | Successful |

These results describe the checks performed during this development cycle. Re-run the commands after making changes to confirm the current state.

## 5. Manual Device Testing

Automated tests do not replace testing the application on a real device.

Recommended manual checks include:

1. Launch the application and confirm the branding appears correctly.
2. Open the exercise library and view exercise details.
3. Grant camera permission and test pose detection.
4. Check repetition counting and exercise feedback for supported movements.
5. Complete a workout and inspect the session summary.
6. Verify that points, profile information, routines, and session history persist after restarting the application.
7. Check voice feedback and workout timers where applicable.

Record any failed scenarios and the device or Android version used during testing.

## 6. Known Testing Limitations

The automated test results do not, by themselves, establish the accuracy of pose detection across all lighting conditions, camera angles, body positions, or Android devices.

Movement-analysis thresholds and exercise-specific behavior should be validated through manual testing.

## 7. Related Documentation

- [Project README](../README.md)
- [Architecture Documentation](architecture.md)
- [Database Documentation](database.md)
