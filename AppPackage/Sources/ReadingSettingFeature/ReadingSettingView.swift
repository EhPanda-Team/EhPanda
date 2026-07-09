import SwiftUI
import AppModels
import Sharing
import Resources
import AppTools
import ComposableArchitecture

public struct ReadingSettingView: View {
    // The reading-setting editor is shared by the Setting tab and the reader sheet. Rather than hold
    // its own `@Shared`, it binds through its store, whose state vends the shared `Setting`; the model
    // clamps keep every write safe. Any orientation side effect stays with the host (the reader drives
    // it from `ReadingReducer`; the Setting tab has none), so this view carries no such logic.
    private let store: StoreOf<ReadingSettingReducer>

    public init(store: StoreOf<ReadingSettingReducer>) {
        self.store = store
    }

    public var body: some View {
        Form {
            Section {
                Picker(.direction, selection: Binding(store.sharedSetting.readingDirection)) {
                    ForEach(ReadingDirection.allCases) {
                        Text($0.value).tag($0)
                    }
                }
                .pickerStyle(.menu)
                Picker(.preloadLimit, selection: Binding(store.sharedSetting.prefetchLimit)) {
                    ForEach(Array(stride(from: 6, through: 18, by: 4)), id: \.self) { value in
                        Text(.RLocalizable.pages(count: value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
                if !DeviceUtil.isPad {
                    Toggle(.enablesLandscape, isOn: Binding(store.sharedSetting.enablesLandscape))
                }
            }
            Section(.readingAppearance) {
                Picker(
                    .separatorHeight,
                    selection: Binding(store.sharedSetting.contentDividerHeight)
                ) {
                    ForEach(Array(stride(from: 0, through: 20, by: 5)), id: \.self) { value in
                        Text(.Constant.pointValue(value)).tag(Double(value))
                    }
                }
                .pickerStyle(.menu)
                .disabled(store.setting.readingDirection != .vertical)
                ScaleFactorRow(
                    scaleFactor: Binding(store.sharedSetting.maximumScaleFactor),
                    labelContent: .maximumScaleFactor,
                    minFactor: 1.5, maxFactor: 10
                )
                ScaleFactorRow(
                    scaleFactor: Binding(store.sharedSetting.doubleTapScaleFactor),
                    labelContent: .doubleTapScaleFactor,
                    minFactor: 1.5, maxFactor: 5
                )
            }
        }
        .navigationTitle(.reading)
    }
}

private struct ScaleFactorRow: View {
    @Binding private var scaleFactor: Double
    private let labelContent: LocalizedStringResource
    private let minFactor: Double
    private let maxFactor: Double

    init(
        scaleFactor: Binding<Double>, labelContent: LocalizedStringResource,
        minFactor: Double, maxFactor: Double
    ) {
        _scaleFactor = scaleFactor
        self.labelContent = labelContent
        self.minFactor = minFactor
        self.maxFactor = maxFactor
    }

    var body: some View {
        VStack {
            HStack {
                Text(labelContent)
                Spacer()
                Text(.Constant.scaleFactor(scaleFactor.roundedString())).foregroundStyle(.tint)
            }
            Slider(
                value: $scaleFactor, in: minFactor...maxFactor, step: 0.5,
                minimumValueLabel: Text(.Constant.scaleFactor(minFactor.roundedString()))
                    .fontWeight(.medium).font(.callout),
                maximumValueLabel: Text(.Constant.scaleFactor(maxFactor.roundedString()))
                    .fontWeight(.medium).font(.callout),
                label: EmptyView.init
            )
        }
        .padding(.vertical, 10)
    }
}

private extension Double {
    func roundedString() -> String {
        roundedString(with: 1)
    }

    func roundedString(with places: Int) -> String {
        String(format: "%.\(places)f", self)
    }
}

struct ReadingSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ReadingSettingView(
                store: .init(initialState: .init(), reducer: ReadingSettingReducer.init)
            )
        }
    }
}
