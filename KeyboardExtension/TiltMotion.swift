import SwiftUI
import CoreMotion

/// Publishes the device's tilt (roll / pitch, each normalised to about -1…1) so
/// UI can put a specular "glint" that tracks how you hold the phone — the
/// tilt-reactive highlight look of the latest iOS. Uses CoreMotion device
/// motion, which needs no usage-permission (unlike pedometer / activity).
///
/// If motion isn't available to the extension it simply never updates and the
/// glint sits centred — a still highlight, still fine.
final class TiltMotion: ObservableObject {
    private let manager = CMMotionManager()
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    private var starts = 0

    /// Reference-counted so several views can start/stop it without fighting.
    func start() {
        starts += 1
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        // Updates arrive on the main queue, so writing @Published here is safe.
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let a = motion?.attitude else { return }
            let r = max(-1, min(1, a.roll / (.pi / 4)))
            let p = max(-1, min(1, a.pitch / (.pi / 4)))
            // Light low-pass so the glint glides instead of jittering.
            self.roll  = self.roll  * 0.82 + r * 0.18
            self.pitch = self.pitch * 0.82 + p * 0.18
        }
    }

    func stop() {
        starts = max(0, starts - 1)
        if starts == 0 { manager.stopDeviceMotionUpdates() }
    }
}

/// A specular highlight that slides across a circular control toward the way the
/// phone is tilted. Kept in its own small view so only this redraws on the ~30fps
/// motion stream — never the whole keyboard.
struct TiltGlint: View {
    @ObservedObject var motion: TiltMotion
    var tint: Color = .white

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                // Main moving specular blob.
                Circle()
                    .fill(RadialGradient(
                        colors: [tint.opacity(0.85), tint.opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: d * 0.55))
                    .frame(width: d * 0.85, height: d * 0.85)
                    .offset(x: CGFloat(motion.roll) * d * 0.34,
                            y: CGFloat(motion.pitch) * d * 0.34)
                // Thin rim light on the tilt-facing edge.
                Circle()
                    .strokeBorder(tint.opacity(0.5), lineWidth: 1)
                    .frame(width: d, height: d)
                    .mask {
                        LinearGradient(
                            colors: [tint, .clear],
                            startPoint: UnitPoint(x: 0.5 + motion.roll * 0.5, y: 0.5 + motion.pitch * 0.5),
                            endPoint: UnitPoint(x: 0.5 - motion.roll * 0.5, y: 0.5 - motion.pitch * 0.5))
                    }
            }
            .frame(width: d, height: d)
            .blendMode(.plusLighter)
            .clipShape(Circle())
            .allowsHitTesting(false)
        }
    }
}
