import AVFoundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

@_silgen_name("falloutPauseIOSAudio")
private func falloutPauseIOSAudio()

@_silgen_name("falloutResumeIOSAudio")
private func falloutResumeIOSAudio()

@MainActor
private final class VaultPadAudioSession {
    static let shared = VaultPadAudioSession()

    private var observers: [NSObjectProtocol] = []

    private init() {}

    func configure() {
        guard observers.isEmpty else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // SDL still has a usable default path if iOS declines activation.
        }

        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { notification in
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

            if type == .began {
                falloutPauseIOSAudio()
                return
            }

            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            guard options.contains(.shouldResume) else { return }
            try? session.setActive(true)
            falloutResumeIOSAudio()
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { notification in
            guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
            falloutPauseIOSAudio()
            try? session.setActive(true)
            falloutResumeIOSAudio()
        })
    }
}

private extension VaultDataImporter {
    static func writeDefaultConfiguration(to documents: URL, displaySize _: CGSize) throws {
        let destination = documents.appendingPathComponent("fallout2.cfg")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }

        let config = """
        [screen]
        resolution_x=640
        resolution_y=480
        scale=1
        windowed=0

        [input]
        touch_mode=hybrid
        touch_sensitivity=1.0

        [ui]
        auto_quick_save=3
        quick_toolbar_visible=1

        [vaultpad]
        display_preset=classic

        """
        try config.write(to: destination, atomically: true, encoding: .utf8)
    }

    static func migrateLegacyComfortDisplay(in documents: URL) {
        let config = documents.appendingPathComponent("fallout2.cfg")
        guard VaultPadConfig.value(section: "vaultpad", key: "display_preset", at: config) == "comfort" else {
            return
        }

        // The former Comfort preset used a wider internal canvas. Fallout's
        // fixed 640-pixel HUD then sat in the middle with black side gutters.
        // Migrate only that legacy value; an explicit More Map choice remains.
        try? VaultPadConfig.set(section: "screen", key: "resolution_x", value: "640", at: config)
        try? VaultPadConfig.set(section: "screen", key: "resolution_y", value: "480", at: config)
        try? VaultPadConfig.set(section: "vaultpad", key: "display_preset", value: "classic", at: config)
    }

    static func writeTouchMode(_ mode: String, to documents: URL) throws {
        let destination = documents.appendingPathComponent("fallout2.cfg")
        var lines = try String(contentsOf: destination, encoding: .utf8)
            .components(separatedBy: .newlines)
        var inInputSection = false
        var replaced = false

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                inInputSection = trimmed.caseInsensitiveCompare("[input]") == .orderedSame
            } else if inInputSection && trimmed.lowercased().hasPrefix("touch_mode=") {
                lines[index] = "touch_mode=\(mode)"
                replaced = true
                break
            }
        }

        if !replaced {
            lines.append(contentsOf: ["", "[input]", "touch_mode=\(mode)"])
        }
        try lines.joined(separator: "\n").write(to: destination, atomically: true, encoding: .utf8)
    }

}

@MainActor
private final class ImportViewModel: ObservableObject {
    enum Phase { case waiting, validating, copying, ready }

    @Published var phase: Phase = .waiting
    @Published var progress = 0.0
    @Published var message: String?

    let documents: URL
    let finish: () -> Void

    init(documents: URL, finish: @escaping () -> Void) {
        self.documents = documents
        self.finish = finish
    }

    func importFolder(_ url: URL) {
        phase = .validating
        progress = 0
        message = nil

        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let manifest = try await Task.detached { try VaultDataImporter.manifest(for: url) }.value
                phase = .copying
                try await Task.detached { [documents] in
                    try VaultDataImporter.copy(manifest, to: documents) { completed in
                        Task { @MainActor in
                            self.progress = manifest.totalBytes == 0 ? 1 : Double(completed) / Double(manifest.totalBytes)
                        }
                    }
                }.value
                try VaultDataImporter.writeDefaultConfiguration(to: documents, displaySize: UIScreen.main.bounds.size)
                phase = .ready
                progress = 1
                message = "Import complete. Your game data stays on this iPad."
            } catch {
                phase = .waiting
                message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func startPlaying(touchMode: String) {
        do {
            try VaultDataImporter.writeTouchMode(touchMode, to: documents)
            finish()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct TouchModeChoice: Identifiable {
    let id: String
    let name: String
    let summary: String
    let icon: String
}

private struct ControlsView: View {
    let finish: (String) -> Void

    @State private var selectedMode = "hybrid"

    private let modes = [
        TouchModeChoice(id: "hybrid", name: "Hybrid", summary: "Tap directly; drag two fingers to pan the map.", icon: "hand.tap"),
        TouchModeChoice(id: "touch", name: "Direct", summary: "Every tap lands where your finger is. Fastest once familiar.", icon: "scope"),
        TouchModeChoice(id: "trackpad", name: "Trackpad", summary: "Drag anywhere to move the cursor, then tap to click.", icon: "rectangle.and.hand.point.up.left"),
    ]

    private let gestures = [
        ("hand.tap", "Tap", "Select, move, or use"),
        ("hand.point.up.left", "Press and hold", "Open the action menu"),
        ("hand.draw", "Two-finger drag", "Pan until you lift both fingers"),
        ("arrow.left.arrow.right", "Alternate action", "The button previews Kick, Punch, or the other equipped item"),
        ("arrow.down", "Three-finger swipe", "Back or Escape"),
        ("highlighter", "Three-finger hold", "Highlight nearby objects"),
        ("square.and.arrow.down", "Four-finger hold", "Quick save"),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.075, green: 0.08, blue: 0.07).ignoresSafeArea()
            HStack(alignment: .top, spacing: 46) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("TOUCH CONTROLS")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
                    Text("Choose how VaultPad should feel.")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ForEach(modes) { mode in
                        Button {
                            selectedMode = mode.id
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: mode.icon)
                                    .font(.title2)
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mode.name).font(.headline)
                                    Text(mode.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.62))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Image(systemName: selectedMode == mode.id ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                            }
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(
                                selectedMode == mode.id ? Color(red: 0.35, green: 0.29, blue: 0.12) : .white.opacity(0.055),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedMode == mode.id ? Color(red: 0.82, green: 0.72, blue: 0.38).opacity(0.7) : .white.opacity(0.08))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 540, alignment: .leading)

                VStack(alignment: .leading, spacing: 18) {
                    Text("GESTURES")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.48))

                    ForEach(Array(gestures.enumerated()), id: \.offset) { _, gesture in
                        HStack(spacing: 14) {
                            Image(systemName: gesture.0)
                                .frame(width: 28)
                                .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(gesture.1).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text(gesture.2).font(.caption).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }

                    Spacer(minLength: 18)
                    Button("Start Playing") { finish(selectedMode) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Color(red: 0.65, green: 0.52, blue: 0.18))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(28)
                .frame(width: 340)
                .frame(minHeight: 510, alignment: .topLeading)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
            }
            .padding(52)
        }
    }
}

private struct ImportView: View {
    @State private var showingImporter = false
    @State private var showingControls = false
    @StateObject var model: ImportViewModel

    var body: some View {
        ZStack {
            Color(red: 0.075, green: 0.08, blue: 0.07).ignoresSafeArea()
            HStack(spacing: 54) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("VAULTPAD")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .tracking(5)
                        .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
                    Text("Bring your own game.\nKeep it on your iPad.")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Select the folder from a legally purchased copy of Fallout 2. VaultPad copies only the data the engine needs. Nothing is downloaded or uploaded.")
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Unofficial and not affiliated with Bethesda, ZeniMax, or Microsoft.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: 470, alignment: .leading)

                VStack(spacing: 18) {
                    Image(systemName: model.phase == .ready ? "checkmark.seal.fill" : "folder.badge.plus")
                        .font(.system(size: 58, weight: .light))
                        .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))

                    if model.phase == .copying {
                        ProgressView(value: model.progress)
                            .tint(Color(red: 0.82, green: 0.72, blue: 0.38))
                        Text("Copying… \(Int(model.progress * 100))%")
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let message = model.message {
                        Text(message)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(model.phase == .ready ? .white.opacity(0.75) : Color(red: 1, green: 0.62, blue: 0.46))
                    }

                    Button(model.phase == .ready ? "Continue" : "Select Game Folder") {
                        if model.phase == .ready { showingControls = true } else { showingImporter = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Color(red: 0.65, green: 0.52, blue: 0.18))
                    .disabled(model.phase == .validating || model.phase == .copying)
                }
                .padding(32)
                .frame(width: 340)
                .frame(minHeight: 310)
                .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 24))
            }
            .padding(54)
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): model.importFolder(url)
            case .failure(let error): model.message = error.localizedDescription
            }
        }
        .fullScreenCover(isPresented: $showingControls) {
            ControlsView { mode in model.startPlaying(touchMode: mode) }
        }
    }
}

@MainActor
private enum BootstrapPresenter {
    static var window: UIWindow?

    static func present(documents: URL, completion: @escaping () -> Void) {
        let finish = {
            window?.isHidden = true
            window = nil
            completion()
        }
        let model = ImportViewModel(documents: documents, finish: finish)
        let controller = UIHostingController(rootView: ImportView(model: model))
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
    }
}

@_cdecl("falloutRunIOSProductBootstrap")
@MainActor
public func falloutRunIOSProductBootstrap() {
    VaultPadAudioSession.shared.configure()

    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    VaultDataImporter.migrateLegacyComfortDisplay(in: documents)
    guard !VaultDataImporter.isReady(in: documents) else { return }

    var finished = false
    let semaphore = DispatchSemaphore(value: 0)
    Task { @MainActor in
        BootstrapPresenter.present(documents: documents) {
            finished = true
            semaphore.signal()
        }
    }

    if Thread.isMainThread {
        while !finished {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
    } else {
        semaphore.wait()
    }
}
