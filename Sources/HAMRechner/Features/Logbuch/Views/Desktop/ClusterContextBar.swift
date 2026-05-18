import SwiftUI

// Tab-Context-Bar für den DXClusters-Tab. Quellen-Toggles + Filter
// binden direkt an den DXClusterViewModel.
struct ClusterContextBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterVM: DXClusterViewModel

    private var theme: AppTheme { themeManager.theme }

    private var statusText: String {
        let total = clusterVM.spots.count
        let filtered = clusterVM.filteredSpots.count
        if filtered == total {
            return "\(total) Spots"
        }
        return "\(filtered) / \(total) Spots (gefiltert)"
    }

    private var hasFilter: Bool {
        clusterVM.filterBand != "Alle"
            || clusterVM.filterMode != "Alle"
            || clusterVM.filterContinent != "Alle"
            || !clusterVM.searchText.isEmpty
            || !clusterVM.showDX || !clusterVM.showSOTA
            || !clusterVM.showPOTA || !clusterVM.showWWFF
    }

    var body: some View {
        TabContextBarShell {
            HStack(spacing: 10) {
                connectionBadge

                Divider().frame(height: 16).background(theme.separator)

                sourceToggles

                Divider().frame(height: 16).background(theme.separator)

                pickerField("Band", selection: $clusterVM.filterBand,
                            options: bandOptions, width: 80)
                pickerField("Mode", selection: $clusterVM.filterMode,
                            options: modeOptions, width: 80)
                pickerField("Kont.", selection: $clusterVM.filterContinent,
                            options: continentOptions, width: 70)

                searchField

                if hasFilter {
                    Button {
                        clusterVM.filterBand = "Alle"
                        clusterVM.filterMode = "Alle"
                        clusterVM.filterContinent = "Alle"
                        clusterVM.searchText = ""
                        clusterVM.showDX = true
                        clusterVM.showSOTA = true
                        clusterVM.showPOTA = true
                        clusterVM.showWWFF = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Zurücksetzen")
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(theme.accentBlue)
                }

                Spacer()

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: Sub-Views

    private var connectionBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(clusterVM.poolStatusLabel)
                .font(.caption2.bold())
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var statusColor: Color {
        switch clusterVM.clusterStatus {
        case .connected:               return theme.accentGreen
        case .connecting, .loggingIn:  return theme.accentYellow
        case .disconnected:            return theme.textDim
        case .error:                   return theme.accentRed
        }
    }

    private var sourceToggles: some View {
        HStack(spacing: 8) {
            sourceCheckbox("DX",   isOn: $clusterVM.showDX,   color: theme.colorDX)
            sourceCheckbox("SOTA", isOn: $clusterVM.showSOTA, color: theme.colorSOTA)
            sourceCheckbox("POTA", isOn: $clusterVM.showPOTA, color: theme.colorPOTA)
            sourceCheckbox("WWFF", isOn: $clusterVM.showWWFF, color: theme.colorWWFF)
        }
    }

    private func sourceCheckbox(_ label: String,
                                isOn: Binding<Bool>,
                                color: Color) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(isOn.wrappedValue ? color : theme.textDim)
        }
        .toggleStyle(.checkbox)
        .controlSize(.mini)
    }

    private func pickerField(_ label: String,
                             selection: Binding<String>,
                             options: [String],
                             width: CGFloat) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            Picker(label, selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .controlSize(.mini)
            .frame(width: width)
        }
    }

    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.caption2)
                .foregroundStyle(theme.textDim)
            TextField("Suche", text: $clusterVM.searchText)
                .textFieldStyle(.plain)
                .font(.caption)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .frame(width: 120)
                .background(theme.bgCard2)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    // MARK: Picker-Optionen

    private var bandOptions: [String] {
        ["Alle"] + Array(Set(clusterVM.spots.compactMap { $0.band.isEmpty ? nil : $0.band })).sorted()
    }
    private var modeOptions: [String] {
        ["Alle"] + Array(Set(clusterVM.spots.compactMap { $0.mode.isEmpty ? nil : $0.mode })).sorted()
    }
    private var continentOptions: [String] {
        ["Alle", "AF", "AN", "AS", "EU", "NA", "OC", "SA"]
    }
}
