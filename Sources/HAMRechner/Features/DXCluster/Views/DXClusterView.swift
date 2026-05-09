import SwiftUI

struct DXClusterView: View {
    @EnvironmentObject var vm: DXClusterViewModel
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedTab = 0
    @State private var heatmapMinutes = 60
    @State private var utcTime = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            connectionBar
            Divider()
            HSplitView {
                leftPanel
                    .frame(minWidth: 500)
                PropagationPanelView(
                    propagation: vm.propagation,
                    bandMatrix:  vm.bandMatrix(minutes: heatmapMinutes),
                    theme:       theme
                )
                .frame(minWidth: 240, idealWidth: 300, maxWidth: 380)
            }
        }
        .background(theme.bgApp)
        .preferredColorScheme(theme.colorScheme)
        .navigationTitle("DX-Cluster")
        .onAppear {
            updateClock()
            vm.connect()
        }
        .onDisappear { /* keep connection alive while app runs */ }
        .onReceive(timer) { _ in updateClock() }
    }

    // MARK: - Connection bar

    private var connectionBar: some View {
        HStack(spacing: 16) {
            statusDot(vm.clusterStatus, label: "dxspider.funkwelt.net")
            statusDot(.disconnected, label: "SOTAwatch3", dimmed: true)
            statusDot(.disconnected, label: "POTA", dimmed: true)
            Spacer()
            Text("QTH: JN47PN")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            dxSpotButton
            Text(utcTime + " UTC")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.bgSubPanel)
    }

    private func statusDot(_ status: ClusterClient.Status, label: String, dimmed: Bool = false) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(status, dimmed: dimmed))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(dimmed ? theme.textDim : theme.textSecondary)
        }
    }

    private func statusColor(_ s: ClusterClient.Status, dimmed: Bool) -> Color {
        if dimmed { return theme.textDim }
        switch s {
        case .connected:               return theme.accentGreen
        case .connecting, .loggingIn:  return theme.accentYellow
        case .error:                   return theme.accentRed
        default:                       return theme.textDim
        }
    }

    private var dxSpotButton: some View {
        Button("▶ DX SPOT") {}
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(theme.accentBlue)
    }

    // MARK: - Left panel (tabs + log)

    private var leftPanel: some View {
        VSplitView {
            VStack(spacing: 0) {
                tabBar
                filterBar
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            ClusterLogView(messages: vm.logMessages, theme: theme)
                .frame(minHeight: 100, idealHeight: 200)
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Spot-Liste", index: 0)
            tabButton("Bandmap",    index: 1)
            tabButton("Weltkarte",  index: 2)
            tabButton("Statistik",  index: 3)
            Spacer()
        }
        .background(theme.bgPanel)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button(title) { selectedTab = index }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(selectedTab == index ? theme.accentBlue.opacity(0.15) : .clear)
            .foregroundStyle(selectedTab == index ? theme.accentBlue : theme.textSecondary)
            .font(selectedTab == index ? .callout.bold() : .callout)
            .overlay(alignment: .bottom) {
                if selectedTab == index {
                    Rectangle().fill(theme.accentBlue).frame(height: 2)
                }
            }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            filterPicker("Band", options: ["Alle"] + allBandNames(), selection: $vm.filterBand)
            filterPicker("Mode", options: ["Alle","FT8","CW","SSB","AM","FM","RTTY","FT4","WSPR"],
                         selection: $vm.filterMode)
            filterPicker("Kont.", options: ["Alle"] + CONTINENTS,
                         selection: $vm.filterContinent)

            Divider().frame(height: 20)

            Text("Quelle:").font(.caption).foregroundStyle(theme.textSecondary)
            srcCheck("DX",   color: theme.colorDX,   binding: $vm.showDX)
            srcCheck("SOTA", color: theme.colorSOTA,  binding: $vm.showSOTA)
            srcCheck("POTA", color: theme.colorPOTA,  binding: $vm.showPOTA)
            srcCheck("WWFF", color: theme.colorWWFF,  binding: $vm.showWWFF)

            Divider().frame(height: 20)
            TextField("Suche", text: $vm.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)

            Button("Reset") { vm.resetFilters() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.accentRed)

            Spacer()
            Text("\(vm.spotCount) Spots")
                .font(.caption.bold())
                .foregroundStyle(theme.accentBlue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.bgPanel)
    }

    private func filterPicker(_ label: String, options: [String], selection: Binding<String>) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.caption).foregroundStyle(theme.textSecondary)
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(width: 90)
        }
    }

    private func srcCheck(_ label: String, color: Color, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(label).font(.caption.bold()).foregroundStyle(color)
        }
        .toggleStyle(.checkbox)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            SpotListView(spots: vm.filteredSpots, theme: theme)
        case 1:
            PlaceholderView(title: "Bandmap", icon: "waveform.path.ecg")
        case 2:
            PlaceholderView(title: "Weltkarte", icon: "map")
        case 3:
            PlaceholderView(title: "Statistik", icon: "chart.bar")
        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func updateClock() {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        utcTime = f.string(from: Date())
    }
}
