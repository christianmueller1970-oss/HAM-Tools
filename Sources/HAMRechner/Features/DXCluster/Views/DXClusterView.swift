import SwiftUI

struct DXClusterView: View {
    @EnvironmentObject var vm:           DXClusterViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var clusterStore: ClusterSettingsStore
    @EnvironmentObject var watchList:    WatchListStore

    @AppStorage("qthLocator") private var qthLocator = "JN47PN"

    @State private var selectedTab    = 0
    @State private var heatmapMinutes = 60
    @State private var utcTime        = ""
    @State private var localTime      = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            connectionBar
            Divider()
            HSplitView {
                leftPanel
                    .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
                PropagationPanelView(
                    propagation: vm.propagation,
                    bandMatrix:  vm.bandMatrix(minutes: heatmapMinutes),
                    theme:       theme,
                    callsign:    vm.myCallsign,
                    connected:   vm.clusterStatus == .connected,
                    spots:       vm.spots,
                    onSend:      { freq, call, comment in vm.sendSpot(freq: freq, call: call, comment: comment) }
                )
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 360, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgApp)
        .preferredColorScheme(theme.colorScheme)
        .navigationTitle("DX-Cluster")
        .onAppear {
            updateClock()
            // setup + connect läuft jetzt zentral in ContentView.onAppear,
            // damit Band Activity / POTA-Spots / Propagation auch verfügbar
            // sind wenn der User nicht via DX-Cluster-Tab einsteigt.
        }
        .onDisappear { /* keep connection alive while app runs */ }
        .onReceive(timer) { _ in updateClock() }
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

            Text("QTH: \(qthLocator)")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            if vm.alertCount > 0 {
                Label("\(vm.alertCount)", systemImage: "bell.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .onTapGesture { vm.alertCount = 0 }
            }


            Text(utcTime + " UTC")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textPrimary)

            Text(localTime + " LT")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
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

    // MARK: - Left panel (tabs + log)

    private var leftPanel: some View {
        VSplitView {
            VStack(spacing: 0) {
                tabBar
                    .fixedSize(horizontal: false, vertical: true)
                filterBar
                    .fixedSize(horizontal: false, vertical: true)
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ClusterLogView(messages: vm.logMessages, theme: theme)
                .frame(minHeight: 80, idealHeight: 160, maxHeight: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity)
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
        Menu {
            ForEach(options, id: \.self) { opt in
                Button {
                    selection.wrappedValue = opt
                } label: {
                    if opt == selection.wrappedValue {
                        Label(opt, systemImage: "checkmark")
                    } else {
                        Text(opt)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(label):")
                    .font(.caption.bold())
                    .foregroundStyle(theme.textSecondary)
                Text(selection.wrappedValue)
                    .font(.caption.bold())
                    .foregroundStyle(selection.wrappedValue == "Alle" ? theme.textPrimary : theme.accentBlue)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textDim)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.bgSubPanel)
            .cornerRadius(5)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
    }

    private var radiusPicker: some View {
        Menu {
            Button("Alle")     { vm.spotterRadiusKm = 0 }
            Button("500 km")   { vm.spotterRadiusKm = 500 }
            Button("1000 km")  { vm.spotterRadiusKm = 1000 }
            Button("2500 km")  { vm.spotterRadiusKm = 2500 }
            Button("5000 km")  { vm.spotterRadiusKm = 5000 }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "location.circle")
                    .font(.caption)
                    .foregroundStyle(vm.spotterRadiusKm > 0 ? theme.accentBlue : theme.textSecondary)
                Text("Radius:")
                    .font(.caption.bold())
                    .foregroundStyle(theme.textSecondary)
                Text(vm.spotterRadiusKm == 0 ? "Alle" : "\(vm.spotterRadiusKm) km")
                    .font(.caption.bold())
                    .foregroundStyle(vm.spotterRadiusKm > 0 ? theme.accentBlue : theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textDim)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.bgSubPanel)
            .cornerRadius(5)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
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
        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        utcTime = f.string(from: now)
        f.timeZone = TimeZone.current
        localTime = f.string(from: now)
    }
}
