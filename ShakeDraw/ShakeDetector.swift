import CoreMotion
import Foundation

class ShakeDetector: ObservableObject {
    private let motionManager = CMMotionManager()
    private var shakeThreshold: Double = 1.8  // 从2.5降低到1.8，提高灵敏度
    private var lastShakeTime: Date = Date()
    private let shakeTimeInterval: TimeInterval = 0.6  // 从1.0降低到0.6秒，允许更频繁触发
    
    @Published var onShakeDetected: (() -> Void)?
    @Published var accelerometerAvailable: Bool = true
    
    init() {
        startAccelerometerUpdates()
    }
    
    private func startAccelerometerUpdates() {
        guard motionManager.isAccelerometerAvailable else {
            accelerometerAvailable = false
            #if targetEnvironment(simulator)
            print("ℹ️ Accelerometer not available in Simulator; use the button to draw.")
            #else
            print("ℹ️ Accelerometer not available on this device.")
            #endif
            return
        }

        motionManager.accelerometerUpdateInterval = 0.05  // 从0.1降低到0.05，提高检测频率
        accelerometerAvailable = true
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }
            
            let acceleration = data.acceleration
            // 使用更敏感的计算方式，去除重力影响
            let totalAcceleration = abs(acceleration.x) + abs(acceleration.y) + abs(acceleration.z)
            let magnitude = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
            
            // 两种检测方式：总加速度或矢量幅值，任一满足即触发
            if totalAcceleration > self.shakeThreshold * 1.2 || magnitude > self.shakeThreshold {
                let now = Date()
                if now.timeIntervalSince(self.lastShakeTime) > self.shakeTimeInterval {
                    self.lastShakeTime = now
                    print("🎯 摇一摇触发！总加速度: \(String(format: "%.2f", totalAcceleration)), 矢量幅值: \(String(format: "%.2f", magnitude))")
                    DispatchQueue.main.async {
                        self.onShakeDetected?()
                    }
                }
            }
        }
    }
    
    func setShakeCallback(_ callback: @escaping () -> Void) {
        onShakeDetected = callback
    }
    
    deinit {
        motionManager.stopAccelerometerUpdates()
    }
}
