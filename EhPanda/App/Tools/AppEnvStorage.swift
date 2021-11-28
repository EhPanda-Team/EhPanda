//
//  AppEnvStorage.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/10.
//

@propertyWrapper
struct AppEnvStorage<T: Encodable> {
    private var key: String
    private var value: T?

    private var appEnv: AppEnv {
        PersistenceController.fetchAppEnvNonNil()
    }

    private var fetchedValue: T! {
        let mirror = Mirror(reflecting: appEnv)
        for child in mirror.children where child.label == key {
            if let value = child.value as? T {
                return value
            }
        }
        Logger.error("Failed in force downcasting to generic type...")
        return nil
    }

    var wrappedValue: T {
        get {
            value ?? fetchedValue
        }
        set {
            value = newValue
            PersistenceController.update { appEnvMO in
                appEnvMO.setValue(newValue.toData(), forKeyPath: key)
            }
        }
    }

    init(type: T.Type, key: String? = nil) {
        if let key = key {
            self.key = key
        } else {
            self.key = String(describing: type).lowercased()
        }
        value = fetchedValue
    }
}
