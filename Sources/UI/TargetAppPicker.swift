import SwiftUI

// MARK: - Target App Picker

/// Dropdown menu for selecting the target application that receives transcribed text.
/// Includes an "Auto (Frontmost)" option and sorts developer tools to the top.
public struct TargetAppPicker: View {
    @Binding private var selectedApp: TargetApp?
    private let availableApps: [TargetApp]

    public init(
        selectedApp: Binding<TargetApp?>,
        availableApps: [TargetApp]
    ) {
        self._selectedApp = selectedApp
        self.availableApps = availableApps
    }

    public var body: some View {
        Menu {
            autoFrontmostButton

            if !sortedApps.isEmpty {
                Divider()
            }

            ForEach(sortedApps) { app in
                appButton(for: app)
            }
        } label: {
            menuLabel
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Menu Items

    private var autoFrontmostButton: some View {
        Button {
            selectedApp = nil
        } label: {
            HStack {
                Text("Auto (Frontmost)")

                if selectedApp == nil {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func appButton(for app: TargetApp) -> some View {
        Button {
            selectedApp = app
        } label: {
            HStack {
                Text(app.name)

                if selectedApp?.id == app.id {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    // MARK: - Label

    private var menuLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: selectedApp == nil ? "macwindow" : "app.fill")
                .font(.system(size: 12))

            Text(selectedApp?.name ?? "Frontmost")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Sorting

    /// Developer tools appear first, then alphabetical within each group.
    private var sortedApps: [TargetApp] {
        availableApps.sorted { lhs, rhs in
            if lhs.isDeveloperTool != rhs.isDeveloperTool {
                return lhs.isDeveloperTool
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

// MARK: - Preview

#if DEBUG
private let sampleApps: [TargetApp] = [
    TargetApp(id: 1, bundleIdentifier: "com.microsoft.VSCode", name: "Visual Studio Code"),
    TargetApp(id: 2, bundleIdentifier: "com.apple.Safari", name: "Safari"),
    TargetApp(id: 3, bundleIdentifier: "com.apple.Notes", name: "Notes"),
    TargetApp(id: 4, bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode")
]

#Preview {
    TargetAppPicker(
        selectedApp: .constant(nil),
        availableApps: sampleApps
    )
    .padding()
}
#endif
