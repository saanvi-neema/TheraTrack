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

        if let shoulder = point(.leftShoulder), let hip = point(.leftHip), let elbow = point(.leftElbow) {
            result["leftShoulderAbduction"] = angle(at: shoulder, from: hip, to: elbow)
        }
        if let shoulder = point(.rightShoulder), let hip = point(.rightHip), let elbow = point(.rightElbow) {
            result["rightShoulderAbduction"] = angle(at: shoulder, from: hip, to: elbow)
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
