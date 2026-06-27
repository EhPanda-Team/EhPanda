import SwiftUI
import AppModels
import Utilities

// Binds the pure, host-parameterized color on the model types to the host the user is
// currently browsing. The runtime lookup (UserDefaults via AppUtil) lives here in the app
// layer so the model types stay free of that dependency.
extension AppModels.Category {
    var color: Color {
        color(host: AppUtil.galleryHost)
    }
}

extension Gallery {
    var color: Color {
        category.color
    }
}
