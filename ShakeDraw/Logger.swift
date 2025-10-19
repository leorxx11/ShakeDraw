import Foundation

enum AppLog {
    // 默认关闭详细日志；如需临时开启，可将其改为 true
    static var verbose: Bool = false

    static func d(_ message: @autoclosure () -> String) {
        if verbose { print(message()) }
    }

    static func i(_ message: @autoclosure () -> String) {
        if verbose { print(message()) }
    }

    static func w(_ message: @autoclosure () -> String) {
        if verbose { print(message()) }
    }

    static func e(_ message: @autoclosure () -> String) {
        print(message())
    }
}

