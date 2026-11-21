public import AnalyticsClient

/// Splits a recorded signal list for a test whose signals come from concurrently running effects. Each partition
/// keeps its recorded order and is asserted exactly; no order is assumed between the two, and together they are the
/// whole list.
extension [AnalyticsSignal] {
    /// The `errorSurfaced` signals, in recorded order.
    public var errorSignals: [AnalyticsSignal] {
        filter({ signal in
            if case .errorSurfaced = signal { return true }
            return false
        })
    }

    /// Every other signal, in recorded order.
    public var nonErrorSignals: [AnalyticsSignal] {
        filter({ signal in
            if case .errorSurfaced = signal { return false }
            return true
        })
    }
}
