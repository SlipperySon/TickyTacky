import Foundation

/// UserDefaults-backed Pomodoro defaults (local only).
enum FocusSettings {
    private static let workKey = "focus.workMinutes"
    private static let shortKey = "focus.shortBreakMinutes"
    private static let longKey = "focus.longBreakMinutes"
    private static let cycleKey = "focus.sessionsUntilLongBreak"
    private static let autoBreakKey = "focus.autoStartBreak"
    private static let autoWorkKey = "focus.autoStartWork"

    static var workMinutes: Int {
        get { clamped(UserDefaults.standard.object(forKey: workKey) as? Int ?? 25, 1...90) }
        set { UserDefaults.standard.set(clamped(newValue, 1...90), forKey: workKey) }
    }

    static var shortBreakMinutes: Int {
        get { clamped(UserDefaults.standard.object(forKey: shortKey) as? Int ?? 5, 1...30) }
        set { UserDefaults.standard.set(clamped(newValue, 1...30), forKey: shortKey) }
    }

    static var longBreakMinutes: Int {
        get { clamped(UserDefaults.standard.object(forKey: longKey) as? Int ?? 15, 1...60) }
        set { UserDefaults.standard.set(clamped(newValue, 1...60), forKey: longKey) }
    }

    static var sessionsUntilLongBreak: Int {
        get { clamped(UserDefaults.standard.object(forKey: cycleKey) as? Int ?? 4, 2...8) }
        set { UserDefaults.standard.set(clamped(newValue, 2...8), forKey: cycleKey) }
    }

    static var autoStartBreak: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoBreakKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: autoBreakKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoBreakKey) }
    }

    static var autoStartWork: Bool {
        get { UserDefaults.standard.bool(forKey: autoWorkKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoWorkKey) }
    }

    static func durationSeconds(for kind: FocusSessionKind) -> Int {
        switch kind {
        case .work: workMinutes * 60
        case .shortBreak: shortBreakMinutes * 60
        case .longBreak: longBreakMinutes * 60
        }
    }

    private static func clamped(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
