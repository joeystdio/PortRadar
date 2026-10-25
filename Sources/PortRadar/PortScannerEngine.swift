import Foundation
import AppKit
import Carbon
import Combine

enum PortCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case dev = "Dev Servers"
    case database = "Databases & Infra"
    case system = "System & Other"
    
    var id: String { rawValue }
}

struct ListeningPort: Identifiable, Equatable {
    var id: String { "\(port)-\(pid)" }
    let port: Int
    let pid: Int32
    let processName: String
    let fullCommand: String
    let address: String
    let user: String
    let cpuPercent: Double
    let memoryMB: Double
    let frameworkTag: String
    let iconSymbol: String
    let badgeColorName: String
    let category: PortCategory
    
    var localhostURL: URL? {
        URL(string: "http://localhost:\(port)")
    }
}

@MainActor
final class PortScannerEngine: ObservableObject {
    static let shared = PortScannerEngine()
    
    @Published var ports: [ListeningPort] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: PortCategory = .all
    @Published var pinnedPorts: [Int] = [3000, 5173, 8080, 5000, 5432, 6379] {
        didSet {
            UserDefaults.standard.set(pinnedPorts, forKey: "pinnedPorts")
        }
    }
    @Published var autoRefreshSeconds: Int = 3 {
        didSet {
            UserDefaults.standard.set(autoRefreshSeconds, forKey: "autoRefreshSeconds")
            restartRefreshTimer()
        }
    }
    @Published var hideSystemmacOSServices: Bool = true {
        didSet {
            UserDefaults.standard.set(hideSystemmacOSServices, forKey: "hideSystemmacOSServices")
        }
    }
    @Published var lastKilledMessage: String? = nil
    @Published var isScanning: Bool = false
    
    var onUpdate: (() -> Void)?
    
    private var refreshTimer: Timer?
    private var hotKeyRef: EventHotKeyRef?
    
    private init() {
        let d = UserDefaults.standard
        if let savedPins = d.array(forKey: "pinnedPorts") as? [Int], !savedPins.isEmpty {
            pinnedPorts = savedPins
        }
        if d.object(forKey: "autoRefreshSeconds") != nil {
            let val = d.integer(forKey: "autoRefreshSeconds")
            if val > 0 { autoRefreshSeconds = val }
        }
        if d.object(forKey: "hideSystemmacOSServices") != nil {
            hideSystemmacOSServices = d.bool(forKey: "hideSystemmacOSServices")
        }
        
        setupGlobalHotkey()
        scanNow()
        restartRefreshTimer()
    }
    
    var filteredPorts: [ListeningPort] {
        ports.filter { item in
            if hideSystemmacOSServices && item.category == .system && !pinnedPorts.contains(item.port) {
                if selectedCategory != .system {
                    return false
                }
            }
            if selectedCategory != .all && item.category != selectedCategory {
                return false
            }
            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                let q = searchText.lowercased()
                let matchPort = "\(item.port)".contains(q)
                let matchProc = item.processName.lowercased().contains(q)
                let matchTag = item.frameworkTag.lowercased().contains(q)
                let matchCmd = item.fullCommand.lowercased().contains(q)
                let matchPid = "\(item.pid)".contains(q)
                return matchPort || matchProc || matchTag || matchCmd || matchPid
            }
            return true
        }
    }
    
    var devServerCount: Int {
        ports.filter { $0.category == .dev || $0.category == .database }.count
    }
    
    func togglePin(port: Int) {
        if let idx = pinnedPorts.firstIndex(of: port) {
            pinnedPorts.remove(at: idx)
        } else {
            pinnedPorts.append(port)
            pinnedPorts.sort()
        }
    }
    
    func addPinnedPort(_ port: Int) {
        guard port > 0 && port <= 65535 else { return }
        if !pinnedPorts.contains(port) {
            pinnedPorts.append(port)
            pinnedPorts.sort()
        }
    }
    
    func activePortItem(for portNumber: Int) -> ListeningPort? {
        ports.first(where: { $0.port == portNumber })
    }
    
    func killProcess(_ item: ListeningPort, force: Bool = false) {
        let sig: Int32 = force ? SIGKILL : SIGTERM
        let result = kill(item.pid, sig)
        if result == 0 {
            showToast("Killed :\(item.port) (\(item.frameworkTag), PID \(item.pid))")
        } else {
            // Fallback via /bin/kill
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/kill")
            proc.arguments = [force ? "-9" : "-15", "\(item.pid)"]
            try? proc.run()
            proc.waitUntilExit()
            showToast("Sent \(force ? "SIGKILL" : "SIGTERM") to :\(item.port) (PID \(item.pid))")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            Task { @MainActor in
                PortScannerEngine.shared.scanNow()
            }
        }
    }
    
    func openInBrowser(port: Int) {
        if let url = URL(string: "http://localhost:\(port)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func copyURL(port: Int) {
        let str = "http://localhost:\(port)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        showToast("Copied \(str)")
    }
    
    private func showToast(_ msg: String) {
        lastKilledMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            Task { @MainActor in
                if PortScannerEngine.shared.lastKilledMessage == msg {
                    PortScannerEngine.shared.lastKilledMessage = nil
                }
            }
        }
    }
    
    private func restartRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(max(2, autoRefreshSeconds)), repeats: true) { _ in
            Task { @MainActor in
                PortScannerEngine.shared.scanNow()
            }
        }
    }
    
    func scanNow() {
        guard !isScanning else { return }
        isScanning = true
        let pinnedSnapshot = pinnedPorts
        
        DispatchQueue.global(qos: .userInitiated).async {
            let discovered = Self.performSystemPortScan(pinned: pinnedSnapshot)
            DispatchQueue.main.async {
                let engine = PortScannerEngine.shared
                engine.ports = discovered
                engine.isScanning = false
                engine.onUpdate?()
            }
        }
    }
    
    // MARK: - Background lsof + ps parser
    nonisolated private static func performSystemPortScan(pinned: [Int]) -> [ListeningPort] {
        // 1. Run lsof -iTCP -sTCP:LISTEN -P -n -F pcnTu
        let lsofOutput = runCommand("/usr/sbin/lsof", args: ["-iTCP", "-sTCP:LISTEN", "-P", "-n", "-F", "pcnTu"])
        
        struct RawListener {
            var pid: Int32
            var command: String
            var user: String
            var port: Int
            var address: String
        }
        
        var rawListeners: [RawListener] = []
        var currentPid: Int32 = 0
        var currentCmd: String = ""
        var currentUser: String = ""
        
        for line in lsofOutput.split(separator: "\n") {
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())
            switch prefix {
            case "p":
                currentPid = Int32(value) ?? 0
            case "c":
                currentCmd = value
            case "u":
                currentUser = value
            case "n":
                // e.g. *:3000 or 127.0.0.1:5432 or [::1]:8080
                if let colonIdx = value.lastIndex(of: ":") {
                    let addrPart = String(value[..<colonIdx])
                    let portPart = String(value[value.index(after: colonIdx)...])
                    if let portNum = Int(portPart), currentPid > 0 {
                        rawListeners.append(
                            RawListener(
                                pid: currentPid,
                                command: currentCmd,
                                user: currentUser,
                                port: portNum,
                                address: addrPart == "*" ? "0.0.0.0" : addrPart
                            )
                        )
                    }
                }
            default:
                break
            }
        }
        
        // Deduplicate by (port, pid) preferring IPv4/localhost representation
        var uniqueByPortPid: [String: RawListener] = [:]
        for item in rawListeners {
            let key = "\(item.port)-\(item.pid)"
            if uniqueByPortPid[key] == nil {
                uniqueByPortPid[key] = item
            }
        }
        
        let uniquePids = Array(Set(uniqueByPortPid.values.map { $0.pid }))
        var psInfoByPid: [Int32: (cpu: Double, rssKB: Double, args: String)] = [:]
        
        if !uniquePids.isEmpty {
            let pidList = uniquePids.map(String.init).joined(separator: ",")
            let psOut = runCommand("/bin/ps", args: ["-p", pidList, "-o", "pid=,%cpu=,rss=,args="])
            for line in psOut.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                if parts.count >= 3, let pid = Int32(parts[0]) {
                    let cpu = Double(parts[1].replacingOccurrences(of: ",", with: ".")) ?? 0.0
                    let rss = Double(parts[2]) ?? 0.0
                    let args = parts.count == 4 ? String(parts[3]) : ""
                    psInfoByPid[pid] = (cpu, rss, args)
                }
            }
        }
        
        var results: [ListeningPort] = []
        for raw in uniqueByPortPid.values {
            let ps = psInfoByPid[raw.pid]
            let fullCmd = ps?.args.isEmpty == false ? ps!.args : raw.command
            let memMB = (ps?.rssKB ?? 0.0) / 1024.0
            let cpu = ps?.cpu ?? 0.0
            
            let meta = classifyProcess(port: raw.port, processName: raw.command, fullCommand: fullCmd)
            results.append(
                ListeningPort(
                    port: raw.port,
                    pid: raw.pid,
                    processName: raw.command,
                    fullCommand: fullCmd,
                    address: raw.address,
                    user: raw.user,
                    cpuPercent: cpu,
                    memoryMB: memMB,
                    frameworkTag: meta.tag,
                    iconSymbol: meta.icon,
                    badgeColorName: meta.color,
                    category: meta.category
                )
            )
        }
        
        // Sort: Pinned ports first, then Dev Servers, then Databases, then by Port ascending
        return results.sorted { a, b in
            let aPin = pinned.contains(a.port)
            let bPin = pinned.contains(b.port)
            if aPin != bPin { return aPin }
            if a.category != b.category {
                let rank: (PortCategory) -> Int = { cat in
                    switch cat {
                    case .dev: return 0
                    case .database: return 1
                    case .system: return 2
                    case .all: return 3
                    }
                }
                return rank(a.category) < rank(b.category)
            }
            return a.port < b.port
        }
    }
    
    nonisolated private static func classifyProcess(port: Int, processName: String, fullCommand: String) -> (tag: String, icon: String, color: String, category: PortCategory) {
        let lowerName = processName.lowercased()
        let lowerCmd = fullCommand.lowercased()
        
        // 1. Web / Dev Frameworks
        if lowerCmd.contains("next") {
            return ("Next.js", "N.square.fill", "cyan", .dev)
        }
        if lowerCmd.contains("vite") {
            return ("Vite", "bolt.fill", "purple", .dev)
        }
        if lowerCmd.contains("ng serve") || lowerCmd.contains("@angular") {
            return ("Angular", "a.square.fill", "red", .dev)
        }
        if lowerCmd.contains("react-scripts") || lowerCmd.contains("webpack") {
            return ("React / Webpack", "atom", "cyan", .dev)
        }
        if lowerCmd.contains("astro") {
            return ("Astro", "sparkles", "orange", .dev)
        }
        if lowerCmd.contains("nuxt") {
            return ("Nuxt", "triangle.fill", "green", .dev)
        }
        if lowerCmd.contains("remix") {
            return ("Remix", "r.square.fill", "blue", .dev)
        }
        if lowerName.contains("bun") || lowerCmd.contains("bun ") {
            return ("Bun", "hare.fill", "orange", .dev)
        }
        if lowerName.contains("deno") {
            return ("Deno", "terminal.fill", "cyan", .dev)
        }
        if lowerName.contains("node") {
            return ("Node.js", " hexagon.fill", "green", .dev)
        }
        if lowerName.contains("dotnet") || lowerCmd.contains(".dll") || lowerCmd.contains("kestrel") {
            return (".NET / C#", "cube.fill", "purple", .dev)
        }
        if lowerCmd.contains("uvicorn") || lowerCmd.contains("fastapi") {
            return ("FastAPI", "bolt.horizontal.fill", "green", .dev)
        }
        if lowerCmd.contains("django") || lowerCmd.contains("manage.py") {
            return ("Django", "d.square.fill", "green", .dev)
        }
        if lowerCmd.contains("flask") || lowerCmd.contains("gunicorn") {
            return ("Python Web", "terminal.fill", "yellow", .dev)
        }
        if lowerName.contains("python") || lowerName.contains("python3") {
            return ("Python", "chevron.left.forwardslash.chevron.right", "yellow", .dev)
        }
        if lowerName.contains("go") || lowerCmd.contains("go-build") {
            return ("Go", "hare.fill", "cyan", .dev)
        }
        if lowerName.contains("cargo") || lowerCmd.contains("target/debug") || lowerCmd.contains("target/release") {
            return ("Rust", "gearshape.2.fill", "orange", .dev)
        }
        if lowerName.contains("java") || lowerCmd.contains("spring") || lowerCmd.contains("gradle") {
            return ("Java / JVM", "cup.and.saucer.fill", "orange", .dev)
        }
        if lowerName.contains("ruby") || lowerCmd.contains("rails") || lowerCmd.contains("puma") {
            return ("Ruby / Rails", "suit.diamond.fill", "red", .dev)
        }
        if lowerName.contains("php") || lowerCmd.contains("artisan") {
            return ("PHP / Laravel", "server.rack", "purple", .dev)
        }
        
        // 2. Databases & Containers
        if lowerName.contains("postgres") || port == 5432 {
            return ("PostgreSQL", "cylinder.split.1x2.fill", "blue", .database)
        }
        if lowerName.contains("redis") || port == 6379 {
            return ("Redis", "bolt.shield.fill", "red", .database)
        }
        if lowerName.contains("mysqld") || lowerName.contains("mariadbd") || port == 3306 {
            return ("MySQL", "cylinder.fill", "orange", .database)
        }
        if lowerName.contains("mongod") || port == 27017 {
            return ("MongoDB", "leaf.fill", "green", .database)
        }
        if lowerName.contains("docker") || lowerName.contains("com.docke") || lowerName.contains("vpnkit") || lowerName.contains("orbstack") || lowerCmd.contains("docker") {
            return ("Docker / Container", "shippingbox.fill", "blue", .database)
        }
        if lowerName.contains("nginx") || lowerName.contains("caddy") || lowerName.contains("httpd") {
            return ("Web Server", "network", "green", .database)
        }
        if lowerName.contains("ollama") || port == 11434 {
            return ("Ollama LLM", "brain.head.profile", "cyan", .dev)
        }
        
        // 3. Common Dev Ports fallback
        if [3000, 3001, 4000, 4200, 5000, 5001, 5173, 5174, 8000, 8080, 8081, 8888, 9000].contains(port) {
            return (processName, "terminal.fill", "cyan", .dev)
        }
        
        // 4. macOS System / Background Services
        if ["controlce", "rapportd", "sharingd", "airplayxp", "identitys", "launchd", "mDNSRespo", "universal"].contains(where: { lowerName.hasPrefix($0.lowercased()) }) {
            return ("macOS System", "apple.logo", "gray", .system)
        }
        
        return (processName, "network", "gray", .system)
    }
    
    nonisolated private static func runCommand(_ path: String, args: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    // MARK: - Global Hotkey (⌃⌘P)
    private func setupGlobalHotkey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, _, _ in
            Task { @MainActor in
                AppDelegate.sharedInstance?.togglePanelFromHotkey()
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x50524452), id: 1) // 'PRDR'
        let modifiers = UInt32(cmdKey | controlKey)
        let keyCode = UInt32(kVK_ANSI_P) // 'P'
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
