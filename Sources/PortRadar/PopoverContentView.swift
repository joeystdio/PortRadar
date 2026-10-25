import SwiftUI
import AppKit

struct PopoverFrameShape: Shape {
    var arrowX: CGFloat
    var cornerRadius: CGFloat = 16
    var arrowWidth: CGFloat = 24
    var arrowHeight: CGFloat = 11
    
    func path(in rect: CGRect) -> Path {
        let bodyTop = rect.minY + arrowHeight
        let bodyRect = CGRect(x: rect.minX, y: bodyTop, width: rect.width, height: rect.height - arrowHeight)
        let r = cornerRadius
        let clampedX = max(bodyRect.minX + r + arrowWidth / 2 + 6, min(arrowX, bodyRect.maxX - r - arrowWidth / 2 - 6))
        let halfW = arrowWidth / 2
        
        var p = Path()
        p.move(to: CGPoint(x: bodyRect.minX + r, y: bodyRect.minY))
        p.addLine(to: CGPoint(x: clampedX - halfW, y: bodyRect.minY))
        p.addQuadCurve(
            to: CGPoint(x: clampedX - 2.5, y: rect.minY + 1.5),
            control: CGPoint(x: clampedX - halfW * 0.45, y: bodyRect.minY)
        )
        p.addQuadCurve(
            to: CGPoint(x: clampedX + 2.5, y: rect.minY + 1.5),
            control: CGPoint(x: clampedX, y: rect.minY - 0.5)
        )
        p.addQuadCurve(
            to: CGPoint(x: clampedX + halfW, y: bodyRect.minY),
            control: CGPoint(x: clampedX + halfW * 0.45, y: bodyRect.minY)
        )
        p.addLine(to: CGPoint(x: bodyRect.maxX - r, y: bodyRect.minY))
        p.addArc(center: CGPoint(x: bodyRect.maxX - r, y: bodyRect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY - r))
        p.addArc(center: CGPoint(x: bodyRect.maxX - r, y: bodyRect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: bodyRect.minX + r, y: bodyRect.maxY))
        p.addArc(center: CGPoint(x: bodyRect.minX + r, y: bodyRect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: bodyRect.minX, y: bodyRect.minY + r))
        p.addArc(center: CGPoint(x: bodyRect.minX + r, y: bodyRect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

@MainActor
final class PanelGeometryModel: ObservableObject {
    static let shared = PanelGeometryModel()
    @Published var arrowX: CGFloat = 310
}

struct PopoverContentView: View {
    @ObservedObject var engine = PortScannerEngine.shared
    @ObservedObject var geometry = PanelGeometryModel.shared
    @State private var newPinPortString: String = ""
    @State private var showAddPinField: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            headerBar
            pinnedWatchlistBar
            filterAndSearchBar
            
            if let toast = engine.lastKilledMessage {
                toastBanner(toast)
            }
            
            portListScrollArea
            bottomBar
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .padding(.top, 24)
        .frame(width: 620)
        .background(
            ZStack {
                PopoverFrameShape(arrowX: geometry.arrowX)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.12, blue: 0.16),
                                Color(red: 0.08, green: 0.09, blue: 0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                PopoverFrameShape(arrowX: geometry.arrowX)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
        )
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("PortRadar")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(engine.devServerCount) dev active")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Text("Localhost Dev Server & Port Manager")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("⌃⌘P")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .help("Global shortcut to open PortRadar anywhere")
            
            Button {
                engine.scanNow()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text("Scan")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(cardBackground)
    }
    
    // MARK: - Pinned Watchlist Bar (:3000, :5173, :8080, :5000, etc.)
    private var pinnedWatchlistBar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Pinned Watchlist", systemImage: "pin.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if showAddPinField {
                    HStack(spacing: 4) {
                        TextField("Port (e.g. 4200)", text: $newPinPortString)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 95)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .onSubmit {
                                if let p = Int(newPinPortString) {
                                    engine.addPinnedPort(p)
                                }
                                newPinPortString = ""
                                showAddPinField = false
                            }
                        
                        Button("Add") {
                            if let p = Int(newPinPortString) {
                                engine.addPinnedPort(p)
                            }
                            newPinPortString = ""
                            showAddPinField = false
                        }
                        .font(.system(size: 10, weight: .bold))
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .controlSize(.mini)
                    }
                } else {
                    Button {
                        showAddPinField = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                            Text("Watch Port")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(engine.pinnedPorts, id: \.self) { pinPort in
                        let activeItem = engine.activePortItem(for: pinPort)
                        let isOnline = activeItem != nil
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isOnline ? Color.green : Color.gray.opacity(0.45))
                                .frame(width: 7, height: 7)
                            
                            Text(":\(String(pinPort))")
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundColor(isOnline ? .white : .secondary)
                            
                            if let active = activeItem {
                                Text(active.frameworkTag)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                                
                                Button {
                                    engine.openInBrowser(port: pinPort)
                                } label: {
                                    Image(systemName: "safari")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("Open http://localhost:\(pinPort)")
                                
                                Button {
                                    engine.killProcess(active, force: false)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                                .help("Kill \(active.processName) on :\(pinPort)")
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isOnline ? Color.green.opacity(0.12) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(isOnline ? Color.green.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .contextMenu {
                            if let active = activeItem {
                                Button("Open http://localhost:\(pinPort)") {
                                    engine.openInBrowser(port: pinPort)
                                }
                                Button("Kill Process (PID \(active.pid))") {
                                    engine.killProcess(active, force: false)
                                }
                                Button("Force Kill (SIGKILL -9)") {
                                    engine.killProcess(active, force: true)
                                }
                                Divider()
                            }
                            Button("Remove :\(pinPort) from Watchlist") {
                                engine.togglePin(port: pinPort)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(cardBackground)
    }
    
    // MARK: - Filter & Search Bar
    private var filterAndSearchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                TextField("Filter by port, process, Next.js, Docker, PID...", text: $engine.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                
                if !engine.searchText.isEmpty {
                    Button {
                        engine.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            HStack(spacing: 3) {
                ForEach(PortCategory.allCases) { cat in
                    let selected = engine.selectedCategory == cat
                    Button {
                        engine.selectedCategory = cat
                    } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 10.5, weight: .semibold))
                            .fixedSize()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selected ? Color.blue : Color.white.opacity(0.07))
                            .foregroundColor(selected ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Port List Scroll Area
    private var portListScrollArea: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                let items = engine.filteredPorts
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 26))
                            .foregroundColor(.secondary)
                        Text("No matching listening TCP ports found")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Start a dev server (e.g. npm run dev, dotnet run, python -m http.server) or toggle 'Show macOS System' below.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    ForEach(items) { item in
                        portRow(item)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 250)
    }
    
    private func portRow(_ item: ListeningPort) -> some View {
        let isPinned = engine.pinnedPorts.contains(item.port)
        return HStack(spacing: 10) {
            // Pin star button
            Button {
                engine.togglePin(port: item.port)
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundColor(isPinned ? .cyan : .secondary.opacity(0.5))
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .help(isPinned ? "Unpin port :\(item.port)" : "Pin port :\(item.port) to Watchlist")
            
            // Port Badge
            Text(":\(String(item.port))")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
                .frame(width: 64, alignment: .leading)
            
            // Framework & Command Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.frameworkTag)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("PID \(String(item.pid))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    if item.memoryMB > 0 {
                        Text(String(format: "%.0f MB", item.memoryMB))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    if item.cpuPercent >= 0.5 {
                        Text(String(format: "%.1f%% CPU", item.cpuPercent))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
                
                Text(item.fullCommand)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Action Buttons: Copy URL, Open Browser, Kill, Force Kill
            HStack(spacing: 6) {
                Button {
                    engine.copyURL(port: item.port)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Copy http://localhost:\(item.port)")
                
                Button {
                    engine.openInBrowser(port: item.port)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text("Open")
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.22))
                    .foregroundColor(.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Open http://localhost:\(item.port) in default browser")
                
                Menu {
                    Button("Kill Gracefully (SIGTERM -15)") {
                        engine.killProcess(item, force: false)
                    }
                    Button("Force Kill Immediately (SIGKILL -9)") {
                        engine.killProcess(item, force: true)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.slash.fill")
                        Text("Kill")
                    }
                    .font(.system(size: 10.5, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.22))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } primaryAction: {
                    engine.killProcess(item, force: false)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Click to Kill (SIGTERM), or use dropdown for Force Kill (-9)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(cardBackground)
    }
    
    private func toastBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.green.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack(spacing: 10) {
            Toggle("Hide macOS System Services", isOn: $engine.hideSystemmacOSServices)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                if let url = URL(string: "https://buymeacoffee.com/joeystdio") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.yellow)
                    Text("Buy Me a Coffee")
                }
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("Quit")
                }
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
