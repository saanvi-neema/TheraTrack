import Foundation

enum DefaultExercise: String, CaseIterable, Identifiable {
    case sitToStand = "Sit-to-Stand"
    case shoulderAbduction = "Shoulder Abduction"
    case heelSlides = "Heel Slides"
    case kneeExtension = "Knee Extension"
    case anklePumps = "Ankle Pumps"
    case standingMarch = "Standing March"

    var id: String { rawValue }
}
