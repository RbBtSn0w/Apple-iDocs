import Foundation

extension ContinuousClock.Instant {
    /// Elapsed wall-clock time from this instant to now, expressed in fractional
    /// milliseconds. Centralizes the duration math that instrumentation across
    /// iDocsKit, iDocsAdapter, and iDocsApp reports as `durationMs`.
    public func millisecondsElapsed() -> Double {
        let duration = self.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
    }
}
