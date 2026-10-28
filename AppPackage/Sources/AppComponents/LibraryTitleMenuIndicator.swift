import SFSafeSymbols
import SwiftUI

struct LibraryTitleMenuIndicator: View {
    @ScaledMetric(relativeTo: .body) private var diameter = 18.0
    @ScaledMetric(relativeTo: .body) private var chevronSize = 10.0

    var body: some View {
        Image(systemSymbol: .chevronDown)
            .font(.system(size: chevronSize, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: diameter, height: diameter)
            .background(Color(uiColor: .secondarySystemFill), in: .circle)
            .accessibilityHidden(true)
    }
}
