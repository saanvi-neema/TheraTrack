import Foundation
import CoreGraphics
import Vision

struct PoseSnapshot {
    var points: [VNHumanBodyPoseObservation.JointName: (location: CGPoint, confidence: Float)]
    var timestamp: TimeInterval
}

enum JointAngleCalculator {
    private static let confidenceThreshold: Float = 0.3

    /// Named joint angles/measurements used by exercise recognition, rep counting, and form checks.
    /// Angles are in degrees; "*AlignmentOffset" values are unitless (normalized to hip-ankle distance);
    /// "*AnkleLift" is a vertical-displacement proxy since Vision has no foot/toe landmark.
    static func namedAngles(from snapshot: PoseSnapshot) -> [String: Double] {
        var result: [String: Double] = [:]
        let points = snapshot.points

        func point(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let entry = points[name], entry.confidence >= confidenceThreshold else { return nil }
            return entry.location
        }

        if let hip = point(.leftHip), let knee = point(.leftKnee), let ankle = point(.leftAnkle) {
            result["leftKnee"] = angle(at: knee, from: hip, to: ankle)
            result["kneeAlignmentLeft"] = lineDeviation(point: knee, lineStart: hip, lineEnd: ankle)
        }
        if let hip = point(.rightHip), let knee = point(.rightKnee), let ankle = point(.rightAnkle) {
            result["rightKnee"] = angle(at: knee, from: hip, to: ankle)
            result["kneeAlignmentRight"] = lineDeviation(point: knee, lineStart: hip, lineEnd: ankle)
        }

        if let shoulder = point(.leftShoulder), let hip = point(.leftHip), let knee = point(.leftKnee) {
            result["leftHip"] = angle(at: hip, from: shoulder, to: knee)
        }
        if let shoulder = point(.rightShoulder), let hip = point(.rightHip), let knee = point(.rightKnee) {
            result["rightHip"] = angle(at: hip, from: shoulder, to: knee)
        }

        // Abduction is measured as arm *elevation*: the angle between "hanging
        // straight down" and the actual shoulder→wrist direction (0° = arm at your
        // side, ~90° = raised to shoulder height, ~180° = overhead). This requires
        // the arm to actually rise, not just drift sideways — a hand resting low on
        // a thigh or chair armrest (common while standing up from a chair) moves
        // sideways too, but stays low, so it no longer gets mistaken for a real raise.
        if let leftShoulder = point(.leftShoulder), let wrist = point(.leftWrist) {
            result["leftShoulderAbduction"] = elevationAngle(shoulder: leftShoulder, wrist: wrist)
        }
        if let rightShoulder = point(.rightShoulder), let wrist = point(.rightWrist) {
            result["rightShoulderAbduction"] = elevationAngle(shoulder: rightShoulder, wrist: wrist)
        }

        if let shoulder = point(.leftShoulder), let elbow = point(.leftElbow), let wrist = point(.leftWrist) {
            result["leftElbow"] = angle(at: elbow, from: shoulder, to: wrist)
        }
        if let shoulder = point(.rightShoulder), let elbow = point(.rightElbow), let wrist = point(.rightWrist) {
            result["rightElbow"] = angle(at: elbow, from: shoulder, to: wrist)
        }

        if let knee = point(.leftKnee), let ankle = point(.leftAnkle) {
            result["leftAnkleLift"] = Double(knee.y - ankle.y) * 100
        }
        if let knee = point(.rightKnee), let ankle = point(.rightAnkle) {
            result["rightAnkleLift"] = Double(knee.y - ankle.y) * 100
        }

        // A standing knee-raise lifts the thigh mostly *toward the camera*, not
        // sideways across it — viewed head-on, that motion is heavily foreshortened,
        // so the hip-shoulder-knee angle barely changes no matter how high the knee
        // actually goes. Measuring vertical knee-to-hip closing distance instead
        // (scaled by torso length, so it stays accurate regardless of distance from
        // the camera) sidesteps foreshortening entirely without requiring a side view.
        if let leftShoulder = point(.leftShoulder), let rightShoulder = point(.rightShoulder),
           let leftHip = point(.leftHip), let rightHip = point(.rightHip) {
            let shoulderMid = CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2, y: (leftShoulder.y + rightShoulder.y) / 2)
            let hipMid = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
            let torsoLength = Double(hypot(shoulderMid.x - hipMid.x, shoulderMid.y - hipMid.y))
            if torsoLength > 0 {
                if let leftKnee = point(.leftKnee) {
                    result["leftKneeRaise"] = Double(leftHip.y - leftKnee.y) / torsoLength * 100
                }
                if let rightKnee = point(.rightKnee) {
                    result["rightKneeRaise"] = Double(rightHip.y - rightKnee.y) / torsoLength * 100
                }
            }
        }

        return result
    }

    /// Angle at `vertex`, between rays to `a` and `b`, in degrees (0-180).
    private static func angle(at vertex: CGPoint, from a: CGPoint, to b: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let v2 = CGVector(dx: b.x - vertex.x, dy: b.y - vertex.y)
        let mag1 = (v1.dx * v1.dx + v1.dy * v1.dy).squareRoot()
        let mag2 = (v2.dx * v2.dx + v2.dy * v2.dy).squareRoot()
        guard mag1 > 0, mag2 > 0 else { return 0 }
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let cosine = max(-1, min(1, Double(dot / (mag1 * mag2))))
        return acos(cosine) * 180 / .pi
    }

    /// Angle between the downward-vertical direction at `shoulder` and the actual
    /// `shoulder`→`wrist` direction. Vision's points are y-up, so "straight down"
    /// is the vector (0, -1).
    private static func elevationAngle(shoulder: CGPoint, wrist: CGPoint) -> Double {
        let dx = Double(wrist.x - shoulder.x)
        let dy = Double(wrist.y - shoulder.y)
        let magnitude = (dx * dx + dy * dy).squareRoot()
        guard magnitude > 0 else { return 0 }
        let cosine = max(-1, min(1, -dy / magnitude))
        return acos(cosine) * 180 / .pi
    }

    /// Perpendicular distance from `point` to the line through `lineStart`-`lineEnd`,
    /// normalized by the line's length (so it's scale-invariant across distance from camera).
    private static func lineDeviation(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let lineVector = CGVector(dx: lineEnd.x - lineStart.x, dy: lineEnd.y - lineStart.y)
        let length = (lineVector.dx * lineVector.dx + lineVector.dy * lineVector.dy).squareRoot()
        guard length > 0 else { return 0 }
        let cross = (point.x - lineStart.x) * lineVector.dy - (point.y - lineStart.y) * lineVector.dx
        return Double(cross / length) / Double(length)
    }
}
