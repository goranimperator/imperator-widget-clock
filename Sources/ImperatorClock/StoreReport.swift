import ClockCore
import Foundation

/// `ImperatorClock --report <path>` writes everything known about the shared
/// store to a file, and is meant to be launched through `open` rather than from
/// a shell.
///
/// TCC attributes a file request to the *responsible* process, which for a
/// binary started from a terminal is the terminal, not the app. Another app's
/// container is protected, so running `--group-check` from a shell reports a
/// failure that says nothing about whether the app itself can reach the file.
/// Launched by LaunchServices the app is responsible for itself, and this
/// writes its answer somewhere unprotected so the answer can be read back.
enum StoreReport {
    static func run(path: String) -> Int32 {
        // LaunchServices gives the process cwd `/`, so a relative path lands on
        // the read-only root and the write fails with nothing on screen.
        guard path.hasPrefix("/") else {
            FileHandle.standardError.write(
                "--report needs an absolute path; got \(path)\n".data(using: .utf8)!)
            return 2
        }
        var lines: [String] = []
        lines.append("settings=\(SharedStore.settingsURL.path)")
        lines.append("heartbeat=\(SharedStore.heartbeatURL.path)")

        // Raw bytes, not the decoded struct: a decode that silently falls back
        // to its defaults is one of the things being investigated.
        lines.append(contentsOf: dump(SharedStore.settingsURL, label: "settings"))
        lines.append(contentsOf: dump(SharedStore.heartbeatURL, label: "heartbeat"))

        // The write path, with the real error rather than SharedStore's Bool.
        // Create the directory first, the way SharedStore.save does, or the
        // probe reports a missing folder instead of the permission answer.
        let probe = SharedStore.directory.appendingPathComponent("write-probe.tmp")
        do {
            try FileManager.default.createDirectory(at: SharedStore.directory,
                                                    withIntermediateDirectories: true)
            try Data("probe".utf8).write(to: probe, options: .atomic)
            try? FileManager.default.removeItem(at: probe)
            lines.append("write: ok")
        } catch {
            let ns = error as NSError
            lines.append("write: FAILED \(ns.domain) \(ns.code) \(ns.localizedDescription)")
        }

        let text = lines.joined(separator: "\n") + "\n"
        do {
            try text.write(toFile: path, atomically: true, encoding: .utf8)
            FileHandle.standardError.write("wrote \(path)\n".data(using: .utf8)!)
            return 0
        } catch {
            // Launched through `open` nobody sees this, but run from a shell it
            // is the difference between a failed write and a missing flag.
            FileHandle.standardError.write(
                "could not write \(path): \(error.localizedDescription)\n"
                    .data(using: .utf8)!)
            return 1
        }
    }

    private static func dump(_ url: URL, label: String) -> [String] {
        // This app is unsandboxed and, launched by LaunchServices, carries its
        // own TCC grants. Following a symlink someone swapped into the store
        // would turn it into an arbitrary-file-read deputy, so refuse.
        let resolved = url.resolvingSymlinksInPath()
        if resolved.standardizedFileURL != url.standardizedFileURL {
            return ["\(label): REFUSED, \(url.lastPathComponent) is a link to \(resolved.path)"]
        }
        do {
            let data = try Data(contentsOf: url)
            let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes, not UTF-8>"
            return ["\(label): read ok", body]
        } catch {
            let ns = error as NSError
            return ["\(label): FAILED \(ns.domain) \(ns.code) \(ns.localizedDescription)"]
        }
    }
}
