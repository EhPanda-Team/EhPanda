import SwiftUI
import TTProgressHUD
import SwiftUINavigation
import SwiftUINavigationExt

extension View {
    func progressHUD<Enum: Equatable & Sendable, Case: Sendable>(
        config: ProgressHUDConfigState,
        unwrapping enum: Binding<Enum?>,
        case caseKeyPath: CaseKeyPath<Enum, Case>
    ) -> some View {
        ZStack {
            self
            TTProgressHUD(
                `enum`.case(caseKeyPath).isRemovedDuplicatesPresent(),
                config: config.progressHUDConfig
            )
        }
    }
}
