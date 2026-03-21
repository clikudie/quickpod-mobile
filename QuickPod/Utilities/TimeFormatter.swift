import Foundation

enum TimeFormatter {
    /// Formats seconds into "mm:ss" or "h:mm:ss" for display
    static func formatted(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Formats seconds into a compact range string, e.g. "2:15 – 3:40"
    static func range(start: Double, end: Double) -> String {
        "\(formatted(start)) – \(formatted(end))"
    }
}
