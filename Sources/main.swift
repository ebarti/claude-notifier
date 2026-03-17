import Cocoa
import UserNotifications

// MARK: - Constants

let appVersion = "1.0.0"
let defaultTitle = "Claude Code"
let defaultSound = "default"
let listenerTimeout: TimeInterval = 300 // 5 minutes

// MARK: - Usage

func printUsage() {
    let usage = """
    claude-notifier \(appVersion)
    Post macOS notifications from the command line.

    USAGE:
        claude-notifier -message "Hello" [OPTIONS]
        echo "Hello" | claude-notifier [OPTIONS]

    OPTIONS:
        -message VALUE      Notification body (or pipe via stdin)
        -title VALUE        Notification title (default: "Claude Code")
        -subtitle VALUE     Secondary line
        -sound NAME         Sound name (default: "default")
        -group ID           Group identifier (replaces previous in same group)
        -open URL           URL or file path to open on click
        -execute COMMAND    Shell command to run on click
        -timeout SECONDS    Auto-dismiss timeout (default: 0)
        -help               Print this help and exit
        -version            Print version and exit
    """
    print(usage)
}

// MARK: - Argument Parsing

struct NotificationArgs {
    var message: String?
    var title: String = defaultTitle
    var subtitle: String?
    var sound: String = defaultSound
    var group: String?
    var openURL: String?
    var execute: String?
    var timeout: TimeInterval = 0
}

func parseArguments() -> NotificationArgs {
    let args = CommandLine.arguments
    var parsed = NotificationArgs()
    var i = 1

    while i < args.count {
        switch args[i] {
        case "-help", "--help":
            printUsage()
            exit(0)
        case "-version", "--version":
            print(appVersion)
            exit(0)
        case "-message":
            i += 1
            guard i < args.count else {
                fputs("Error: -message requires a value.\n", stderr)
                exit(1)
            }
            parsed.message = args[i]
        case "-title":
            i += 1
            guard i < args.count else {
                fputs("Error: -title requires a value.\n", stderr)
                exit(1)
            }
            parsed.title = args[i]
        case "-subtitle":
            i += 1
            guard i < args.count else {
                fputs("Error: -subtitle requires a value.\n", stderr)
                exit(1)
            }
            parsed.subtitle = args[i]
        case "-sound":
            i += 1
            guard i < args.count else {
                fputs("Error: -sound requires a value.\n", stderr)
                exit(1)
            }
            parsed.sound = args[i]
        case "-group":
            i += 1
            guard i < args.count else {
                fputs("Error: -group requires a value.\n", stderr)
                exit(1)
            }
            parsed.group = args[i]
        case "-open":
            i += 1
            guard i < args.count else {
                fputs("Error: -open requires a value.\n", stderr)
                exit(1)
            }
            parsed.openURL = args[i]
        case "-execute":
            i += 1
            guard i < args.count else {
                fputs("Error: -execute requires a value.\n", stderr)
                exit(1)
            }
            parsed.execute = args[i]
        case "-timeout":
            i += 1
            guard i < args.count else {
                fputs("Error: -timeout requires a value.\n", stderr)
                exit(1)
            }
            guard let seconds = TimeInterval(args[i]) else {
                fputs("Error: -timeout must be a number.\n", stderr)
                exit(1)
            }
            parsed.timeout = seconds
        case "-listen":
            // Internal flag: run as background click listener.
            break
        default:
            fputs("Error: Unknown option '\(args[i])'. Use -help for usage.\n", stderr)
            exit(1)
        }
        i += 1
    }

    return parsed
}

func readStdin() -> String? {
    guard isatty(fileno(stdin)) == 0 else { return nil }
    var lines: [String] = []
    while let line = readLine(strippingNewline: false) {
        lines.append(line)
    }
    let result = lines.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    return result.isEmpty ? nil : result
}

// MARK: - JSON Stdin Parsing (Claude Code hook support)

let notificationTypeSounds: [String: String] = [
    "permission_prompt": "Funk",
    "idle_prompt": "default",
    "auth_success": "Glass",
    "elicitation_dialog": "Blow"
]

let notificationTypeTitles: [String: String] = [
    "permission_prompt": "Permission Needed",
    "idle_prompt": "Claude Code",
    "auth_success": "Authentication",
    "elicitation_dialog": "Input Required"
]

func parseHookJSON(_ raw: String) -> NotificationArgs? {
    guard let data = raw.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    guard let message = json["message"] as? String else { return nil }

    var args = NotificationArgs()
    args.message = message

    let notificationType = json["notification_type"] as? String

    if let title = json["title"] as? String, !title.isEmpty {
        args.title = title
    } else if let nt = notificationType, let typeTitle = notificationTypeTitles[nt] {
        args.title = typeTitle
    }

    if let subtitle = json["subtitle"] as? String, !subtitle.isEmpty {
        args.subtitle = subtitle
    }

    if let nt = notificationType, let typeSound = notificationTypeSounds[nt] {
        args.sound = typeSound
    }

    if let nt = notificationType {
        args.group = "claude-\(nt)"
    }

    return args
}

// MARK: - Terminal Detection

let terminalBundleIDs: [String: String] = [
    "Apple_Terminal": "com.apple.Terminal",
    "iTerm.app": "com.googlecode.iterm2",
    "WarpTerminal": "dev.warp.Warp-Stable",
    "vscode": "com.microsoft.VSCode",
    "ghostty": "com.mitchellh.ghostty",
    "alacritty": "org.alacritty",
    "kitty": "net.kovidgoyal.kitty",
    "WezTerm": "com.github.wez.wezterm",
    "tmux": "com.apple.Terminal",
]

func detectTerminalBundleID() -> String? {
    if let termProgram = ProcessInfo.processInfo.environment["TERM_PROGRAM"],
       let bundleID = terminalBundleIDs[termProgram] {
        return bundleID
    }
    return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
}

func activateApp(bundleID: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-b", bundleID]
    try? process.run()
    process.waitUntilExit()
}

// MARK: - Background Listener

/// Kill any existing listener process before spawning a new one.
func killExistingListener() {
    let pidFile = "/tmp/claude-notifier-listener.pid"
    if let pidStr = try? String(contentsOfFile: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
       let pid = Int32(pidStr) {
        kill(pid, SIGTERM)
        usleep(100_000) // 100ms for cleanup
    }
}

/// Spawn a background copy of ourselves in -listen mode.
func spawnListener() {
    killExistingListener()

    let binaryPath = CommandLine.arguments[0]
    let process = Process()
    process.executableURL = URL(fileURLWithPath: binaryPath)
    process.arguments = ["-listen"]
    // Detach stdin/stdout/stderr so the parent can exit cleanly.
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
}

/// Write our PID so the next notification can kill us.
func writeListenerPID() {
    let pidFile = "/tmp/claude-notifier-listener.pid"
    try? "\(ProcessInfo.processInfo.processIdentifier)".write(toFile: pidFile, atomically: true, encoding: .utf8)
}

func cleanupListenerPID() {
    try? FileManager.default.removeItem(atPath: "/tmp/claude-notifier-listener.pid")
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 12.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let urlString = userInfo["openURL"] as? String {
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                } else {
                    NSWorkspace.shared.open(URL(fileURLWithPath: urlString))
                }
            } else if let command = userInfo["executeCommand"] as? String {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", command]
                try? process.run()
            } else if let bundleID = userInfo["terminalBundleID"] as? String {
                activateApp(bundleID: bundleID)
            }
        }

        completionHandler()
        cleanupListenerPID()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
    }
}

// MARK: - Main

let isListenerMode = CommandLine.arguments.contains("-listen")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let notificationDelegate = NotificationDelegate()
let center = UNUserNotificationCenter.current()
center.delegate = notificationDelegate

if isListenerMode {
    // Background listener mode: stay alive to handle notification clicks.
    writeListenerPID()
    DispatchQueue.main.asyncAfter(deadline: .now() + listenerTimeout) {
        cleanupListenerPID()
        exit(0)
    }
    app.run()
} else {
    // Normal mode: post notification, spawn listener, exit.
    var parsedArgs = parseArguments()

    let message: String
    if let msg = parsedArgs.message {
        message = msg
    } else if let stdinRaw = readStdin() {
        if let hookArgs = parseHookJSON(stdinRaw) {
            message = hookArgs.message!
            if CommandLine.arguments.firstIndex(of: "-title") == nil {
                parsedArgs.title = hookArgs.title
            }
            if CommandLine.arguments.firstIndex(of: "-subtitle") == nil {
                parsedArgs.subtitle = hookArgs.subtitle
            }
            if CommandLine.arguments.firstIndex(of: "-sound") == nil {
                parsedArgs.sound = hookArgs.sound
            }
            if CommandLine.arguments.firstIndex(of: "-group") == nil {
                parsedArgs.group = hookArgs.group
            }
        } else {
            message = stdinRaw
        }
    } else {
        fputs("Error: No message provided. Use -message or pipe via stdin.\n", stderr)
        exit(1)
    }

    // Request authorization.
    let semaphore = DispatchSemaphore(value: 0)
    var authGranted = false

    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if let error = error {
            fputs("Error: Authorization failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
        authGranted = granted
        semaphore.signal()
    }

    semaphore.wait()

    if !authGranted {
        fputs("Warning: Notification permission not granted. Notification may not appear.\n", stderr)
    }

    // Build notification content.
    let content = UNMutableNotificationContent()
    content.title = parsedArgs.title
    content.body = message

    if let subtitle = parsedArgs.subtitle {
        content.subtitle = subtitle
    }

    if parsedArgs.sound == "default" {
        content.sound = .default
    } else {
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: parsedArgs.sound))
    }

    var userInfo: [String: String] = [:]
    if let openURL = parsedArgs.openURL {
        userInfo["openURL"] = openURL
    }
    if let execute = parsedArgs.execute {
        userInfo["executeCommand"] = execute
    }
    if let termBundleID = detectTerminalBundleID() {
        userInfo["terminalBundleID"] = termBundleID
    }
    content.userInfo = userInfo

    let identifier = parsedArgs.group ?? UUID().uuidString

    var trigger: UNNotificationTrigger? = nil
    if parsedArgs.timeout > 0 {
        trigger = UNTimeIntervalNotificationTrigger(timeInterval: parsedArgs.timeout, repeats: false)
    }

    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

    // Deliver the notification.
    center.add(request) { error in
        if let error = error {
            fputs("Error: Failed to deliver notification: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        // Spawn a background listener to handle clicks, then exit.
        spawnListener()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    app.run()
}
