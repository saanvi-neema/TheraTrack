# TheraTrack

  A physical therapy exercise tracker for iOS. Patients leave a PT appointment
  with a home exercise plan and no way to check if they're actually doing it
  correctly. TheraTrack uses the phone's camera to track body position in real
  time, counts reps automatically, and gives spoken/visual feedback when form
  falls outside a prescribed range of motion.

  ## How it works

  1. Create a workout and add exercises in a fixed order, with a target rep
  count for each.
  2. Optionally type in PT instructions or upload a document (PDF/image/text) —
  a Groq-hosted LLM extracts structured constraints (e.g. "don't raise your arm
  past 50 degrees") and attaches them to the relevant exercise.
  3. Start a session. The camera tracks body pose via Apple's Vision framework
  (3D body pose estimation) and walks through the exercises in order, advancing
  automatically once each one's rep target is hit.
  4. During each exercise, the app counts reps and checks form live — flagging
  knee misalignment, moving too fast, exceeding the prescribed range, or falling
  short of the target — with spoken announcements and an on-screen message.
  5. After the session, a summary shows reps completed, range of motion,
  left/right symmetry, and any form corrections, compared against the previous
  session of the same workout. A History tab keeps every past session.

  ## Default exercises

  Sit-to-Stand, Shoulder Abduction, Heel Slides, Knee Extension, Ankle Pumps,
  Standing March.

  ## Tech

  - SwiftUI + SwiftData, built with XcodeGen from `project.yml`
  - Apple Vision framework for real-time body pose tracking (`AVCaptureSession`
  + `VNDetectHumanBodyPose3DRequest`)
  - Groq-hosted LLM for turning free-text PT instructions into structured,
  checkable constraints
  - `AVSpeechSynthesizer` for spoken exercise feedback, iOS 17+

  ## Setup

  \`\`\`
  xcodegen generate
  open TheraTrack.xcodeproj
  \`\`\`

  Requires a Groq API key in a gitignored `Secrets.swift` (not included in the
  repo) for the PT-instruction extraction feature.
