import Foundation
import CoreMotion
import UIKit

/// 管理基于设备姿态的视差/体感跟随效果（低通滤波 + 归一化）
final class MotionParallaxManager: ObservableObject {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()

    // 归一化位移（-1...1），基于重力向量映射，已做低通滤波
    @Published private(set) var normX: Double = 0 // 水平方向（左右）
    @Published private(set) var normY: Double = 0 // 垂直方向（上下）

    // 角度（度数），可用于 3D 倾斜
    @Published private(set) var rollDeg: Double = 0   // 相对基线的滚转角（°）
    @Published private(set) var pitchDeg: Double = 0  // 相对基线的俯仰角（°）

    // 可调参数
    var smoothingAlpha: Double = 0.18 // 低通滤波强度（0-1，越大越灵敏）
    var deadZone: Double = 0.04       // 归一化位移死区，避免轻微噪声

    // 基线（以用户当前握持姿势作为“零点”）
    private var baselineGX: Double = 0
    private var baselineGY: Double = 0
    private var baselineRollDeg: Double = 0
    private var baselinePitchDeg: Double = 0
    private var baselineReady = false
    private var warmupFramesTarget = 18 // ~0.3s @60Hz
    private var warmupFrames = 0
    private var sumGX = 0.0, sumGY = 0.0, sumRollDeg = 0.0, sumPitchDeg = 0.0

    private(set) var isRunning = false

    func start() {
        guard !isRunning else { return }
        guard !UIAccessibility.isReduceMotionEnabled else {
            reset()
            return
        }
        guard motion.isDeviceMotionAvailable else { return }

        isRunning = true
        baselineReady = false
        warmupFrames = 0
        sumGX = 0; sumGY = 0; sumRollDeg = 0; sumPitchDeg = 0
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        // 使用校正后的 Z 竖直坐标系（若不可用则使用默认）
        if motion.isDeviceMotionAvailable {
            motion.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: queue) { [weak self] data, _ in
                guard let self, let dm = data else { return }
                self.process(deviceMotion: dm)
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        motion.stopDeviceMotionUpdates()
        reset()
    }

    private func reset() {
        DispatchQueue.main.async {
            self.normX = 0
            self.normY = 0
            self.rollDeg = 0
            self.pitchDeg = 0
        }
    }

    private func process(deviceMotion dm: CMDeviceMotion) {
        // 重力向量（单位 g），范围大致 -1...1
        let g = dm.gravity

        // 设备方向假设：以竖屏为主（更复杂的朝向映射可后续补充）
        // 右倾时 g.x 为正，屏幕视觉可向反方向微移以增强“深度”。
        let rawGX = max(-1, min(1, g.x))
        let rawGY = max(-1, min(1, -g.y)) // y 轴取反以符合直觉（上为正）

        // 低通滤波：new = old + alpha * (raw - old)
        // 姿态角（弧度->度）
        let rollAbs = dm.attitude.roll * 180 / .pi
        let pitchAbs = dm.attitude.pitch * 180 / .pi

        // 基线采样：启动后的前若干帧，取平均作为零点（避免一上手就前倾）
        if !baselineReady {
            sumGX += rawGX; sumGY += rawGY
            sumRollDeg += rollAbs; sumPitchDeg += pitchAbs
            warmupFrames += 1
            if warmupFrames >= warmupFramesTarget {
                baselineGX = sumGX / Double(warmupFrames)
                baselineGY = sumGY / Double(warmupFrames)
                baselineRollDeg = sumRollDeg / Double(warmupFrames)
                baselinePitchDeg = sumPitchDeg / Double(warmupFrames)
                baselineReady = true
            }
            // 预热阶段直接输出0，避免突兀
            DispatchQueue.main.async { [normX = self.normX, normY = self.normY] in
                self.normX = normX * (1 - self.smoothingAlpha)
                self.normY = normY * (1 - self.smoothingAlpha)
                self.rollDeg = 0
                self.pitchDeg = 0
            }
            return
        }

        // 相对基线的偏移
        var relX = rawGX - baselineGX
        var relY = rawGY - baselineGY

        // 死区处理与压缩，避免轻微噪声导致漂移
        func applyDeadZone(_ v: Double) -> Double {
            let a = abs(v)
            if a <= deadZone { return 0 }
            return (a - deadZone) * (v >= 0 ? 1 : -1)
        }
        relX = applyDeadZone(relX)
        relY = applyDeadZone(relY)

        let filteredX = normX + smoothingAlpha * (relX - normX)
        let filteredY = normY + smoothingAlpha * (relY - normY)

        let rollRel = rollAbs - baselineRollDeg
        let pitchRel = pitchAbs - baselinePitchDeg

        DispatchQueue.main.async {
            self.normX = filteredX
            self.normY = filteredY
            self.rollDeg = rollRel
            self.pitchDeg = pitchRel
        }
    }

    /// 手动重置基线到当前姿态（可在需要时调用，如进入结果页时或用户自定义快捷操作）
    func recenterBaselineNow() {
        // 下一帧用当前采样作为基线
        baselineReady = false
        warmupFrames = 0
        sumGX = 0; sumGY = 0; sumRollDeg = 0; sumPitchDeg = 0
    }
}
