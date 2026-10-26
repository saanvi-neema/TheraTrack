import Foundation
import CoreGraphics
import simd
import Vision

struct PoseSnapshot {
    /// 2D image-space projection of each joint, keyed by joint name — used for
    /// overlay drawing and for the ankle-lift proxy (no 3D advantage there, since
    /// there's no foot/toe landmark in either Vision body-pose API).
    var points2D: [String: (location: CGPoint, confidence: Float)]
    /// True 3D joint position relative to the camera, in meters — used for angle
    /// math, since it isn't distorted by foreshortening the way a 2D projection is.
    var points3D: [String: SIMD3<Float>]
    var timestamp: TimeInterval
}

enum JointAngleCalculator {
    private static let confidenceThreshold: Float = 0.3

    /// Named joint angles/measurements used by exercise recognition, rep counting, and form checks.
    /// Angles are in degrees; "*AlignmentOffset" values are unitless (normalized to limb length);
    /// "*AnkleLift" is a 2D vertical-displacement proxy since Vision has no foot/toe landmark.
    static func namedAngles(from snapshot: PoseSnapshot) -> [String: Double] {
        var result: [String: Double] = [:]

        func point3D(_ name: String) -> SIMD3<Float>? {
            guard let entry = snapshot.points2D[name], entry.confidence >= confidenceThreshold else { return nil }
            return snapshot.points3D[name]
        }
        func point2D(_ name: String) -> CGPoint? {
            guard let entry = snapshot.points2D[name], entry.confidence >= confidenceThreshold else { return nil }
            return entry.location
        }

        if let hip = point3D("leftHip"), let knee = point3D("leftKnee"), let ankle = point3D("leftAnkle") {
            result["leftKnee"] = angle(at: knee, from: hip, to: ankle)
            result["kneeAlignmentLeft"] = lineDeviation(point: knee, lineStart: hip, lineEnd: ankle)
        }
        if let hip = point3D("rightHip"), let knee = point3D("rightKnee"), let ankle = point3D("rightAnkle") {
            result["rightKnee"] = angle(at: knee, from: hip, to: ankle)
            result["kneeAlignmentRight"] = lineDeviation(point: knee, lineStart: hip, lineEnd: ankle)
        }

        // Standing March uses a 2D vertical knee-to-hip distance (torso-length
        // scaled), not a 3D hip angle — a march moves the knee both up AND toward
        // the camera, and depth is the least accurate part of monocular 3D
        // estimation (it has to be inferred, not directly seen the way image
        // position is), so the 3D angle barely moved even for a big real motion.
        // This sidesteps depth entirely by measuring only what's directly visible.
        if let leftShoulder = point2D("leftShoulder"), let rightShoulder = point2D("rightShoulder"),
           let leftHip = point2D("leftHip"), let rightHip = point2D("rightHip") {
            let shoulderMid = CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2, y: (leftShoulder.y + rightShoulder.y) / 2)
            let hipMid = CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
            let torsoLength = Double(hypot(shoulderMid.x - hipMid.x, shoulderMid.y - hipMid.y))
            if torsoLength > 0 {
                if let leftKnee = point2D("leftKnee") {
                    result["leftKneeRaise"] = Double(leftHip.y - leftKnee.y) / torsoLength * 100
                }
                if let rightKnee = point2D("rightKnee") {
                    result["rightKneeRaise"] = Double(rightHip.y - rightKnee.y) / torsoLength * 100
                }
            }
        }

        // Shoulder abduction as the 3D angle at the shoulder between straight down
        // the trunk and the direction to the wrist. "Straight down the trunk" uses
        // the dedicated root (pelvis center) and centerShoulder (shoulder center)
        // joints to build the true trunk axis, then anchors that direction at each
        // individual shoulder.
        // 0° = arm at the side, ~90° = raised to shoulder height, ~180° = overhead.
        if let root = point3D("root"), let centerShoulder = point3D("centerShoulder") {
            let trunkDown = root - centerShoulder
            if let leftShoulder = point3D("leftShoulder"), let leftWrist = point3D("leftWrist") {
                result["leftShoulderAbduction"] = angle(at: leftShoulder, from: leftShoulder + trunkDown, to: leftWrist)
            }
            if let rightShoulder = point3D("rightShoulder"), let rightWrist = point3D("rightWrist") {
                result["rightShoulderAbduction"] = angle(at: rightShoulder, from: rightShoulder + trunkDown, to: rightWrist)
            }
        }

        if let shoulder = point3D("leftShoulder"), let elbow = point3D("leftElbow"), let wrist = point3D("leftWrist") {
            result["leftElbow"] = angle(at: elbow, from: shoulder, to: wrist)
        }
        if let shoulder = point3D("rightShoulder"), let elbow = point3D("rightElbow"), let wrist = point3D("rightWrist") {
            result["rightElbow"] = angle(at: elbow, from: shoulder, to: wrist)
        }

        if let knee = point2D("leftKnee"), let ankle = point2D("leftAnkle") {
            result["leftAnkleLift"] = Double(knee.y - ankle.y) * 100
        }
        if let knee = point2D("rightKnee"), let ankle = point2D("rightAnkle") {
            result["rightAnkleLift"] = Double(knee.y - ankle.y) * 100
        }

        return result
    }

    /// Angle at `vertex`, between rays to `a` and `b`, in degrees (0-180) — a true
    /// 3D angle, not a 2D projection, so it isn't distorted by camera viewing angle.
    private static func angle(at vertex: SIMD3<Float>, from a: SIMD3<Float>, to b: SIMD3<Float>) -> Double {
        let v1 = a - vertex
        let v2 = b - vertex
        let mag1 = Double(length(v1))
        let mag2 = Double(length(v2))
        guard mag1 > 0, mag2 > 0 else { return 0 }
        let cosine = max(-1, min(1, Double(dot(v1, v2)) / (mag1 * mag2)))
        return acos(cosine) * 180 / .pi
    }

    /// Perpendicular distance from `point` to the line through `lineStart`-`lineEnd`,
    /// normalized by the line's length (scale-invariant, same semantics as the old
    /// 2D version even though positions are now real-world meters).
    private static func lineDeviation(point: SIMD3<Float>, lineStart: SIMD3<Float>, lineEnd: SIMD3<Float>) -> Double {
        let lineVector = lineEnd - lineStart
        let lineLength = Double(length(lineVector))
        guard lineLength > 0 else { return 0 }
        let toPoint = point - lineStart
        let crossMag = Double(length(cross(toPoint, lineVector)))
        return (crossMag / lineLength) / lineLength
    }
}
