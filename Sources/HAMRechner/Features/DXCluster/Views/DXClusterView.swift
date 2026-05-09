import SwiftUI

struct DXClusterView: View {
    @EnvironmentObject var vm:           DXClusterViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterStore: ClusterSettingsStore
    @EnvironmentObject var watchList:    WatchListStore

    @Environment(\.openSettings) private var openSettings

    @State private var selectedTab    = 0
    @State private var heatmapMinutes = 60
    @State private var utcTime        = ""
    @State private var showSendSpot   = false

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
            vm.setup(watchStore: watchList)
            if let node = clusterStore.activeNode {
                vm.connect(host: node.host, port: node.port)
            } else {
                vm.connect()
            }
        }
        .onDisappear { /* keep connection alive while app runs */ }
        .onReceive(timer) { _ in updateClock() }
        .sheet(isPresented: $showSendSpot) {
            SendSpotSheet(callsign: vm.myCallsign) { freq, call, comment in
                vm.sendSpot(freq: freq, call: call, comment: comment)
            }
        }
    }

    // MARK: - Connection bar

    private var connectionBar: some View {
        HStack(spacing: 12) {
            // Cluster-Auswahlmenü
            clusterMenu

            Divider().frame(height: 16)

            apiDot(vm.sotaActive, label: "SOTAwatch3")
            apiDot(vm.potaActive, label: "POTA")
            apiDot(vm.wwffActive, label: "WWFF")

            Spacer()

            Text("QTH: JN47PN")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            if vm.alertCount > 0 {
                Label("\(vm.alertCount)", systemImage: "bell.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .onTapGesture { vm.alertCount = 0 }
            }

            dxSpotButton

            Text(utcTime + " UTC")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.bgSubPanel)
    }

    private var clusterMenu: some View {
        Menu {
            ForEach(clusterStore.nodes) { node in
                Button {
                    clusterStore.activeNodeID = node.id
                    vm.reconnect(to: node)
                } label: {
                    HStack {
                        Text(node.name)
                        if clusterStore.activeNodeID == node.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button("Cluster-Einstellungen…") { openSettings() }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(clusterStatusColor(vm.clusterStatus))
                    .frame(width: 8, height: 8)
                Text(clusterStore.activeNode?.name ?? "kein Cluster")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textDim)
            }
        }
        .buttonStyle(.plain)
        .menuStyle(.button)
    }

    private func apiDot(_ active: Bool, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(active ? theme.accentGreen : theme.textDim)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(active ? theme.textSecondary : theme.textDim)
        }
    }

    private func clusterStatusColor(_ s: ClusterClient.Status) -> Color {
        switch s {
        case .connected:               return theme.accentGreen
        case .connecting, .loggingIn:  return theme.accentYellow
        case .error:                   return theme.accentRed
        default:                       return theme.textDim
        }
    }

    private var dxSpotButton: some View {
        Button("▶ DX SPOT") { showSendSpot = true }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(theme.accentBlue)
            .disabled(vm.clusterStatus != .connected)
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
            radiusPicker

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

            Button("Leeren") { vm.clearSpots() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(theme.textDim)

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

    private var radiusPicker: some View {
        HStack(spacing: 2) {
            Image(systemName: "location.circle")
                .font(.caption)
                .foregroundStyle(vm.spotterRadiusKm > 0 ? theme.accentBlue : theme.textSecondary)
            Picker("", selection: $vm.spotterRadiusKm) {
                Text("Alle").tag(0)
                Text("500 km").tag(500)
                Text("1000 km").tag(1000)
                Text("2500 km").tag(2500)
                Text("5000 km").tag(5000)
            }
            .pickerStyle(.menu)
            .frame(width: 82)
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
        case 0: SpotListView(spots: vm.filteredSpots, theme: theme, watchList: watchList)
        case 1: BandmapView(spots:   vm.filteredSpots, theme: theme)
        case 2: WeltkarteView(spots: vm.filteredSpots, theme: theme)
        case 3: StatistikView(spots: vm.spots,         theme: theme)
        default: EmptyView()
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
