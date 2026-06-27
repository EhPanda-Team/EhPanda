private final class Reference<T: Equatable>: Equatable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
    static func == (lhs: Reference<T>, rhs: Reference<T>) -> Bool {
        lhs.value == rhs.value
    }
}

@propertyWrapper struct Heap<T: Equatable>: Equatable {
    private var reference: Reference<T>

    init(_ value: T) {
        reference = .init(value)
    }

    var wrappedValue: T {
        get { reference.value }
        set {
            if !isKnownUniquelyReferenced(&reference) {
                reference = .init(newValue)
                return
            }
            reference.value = newValue
        }
    }
    var projectedValue: Heap<T> {
        self
    }
}
