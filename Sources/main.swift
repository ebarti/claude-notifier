import Cocoa
import UserNotifications

// MARK: - Constants

let appVersion = "1.0.0"
let defaultTitle = "Claude Code"
let defaultSound = "default"

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
    var i = 1 // skip executable name

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

/// Default sounds per notification type.
let notificationTypeSounds: [String: String] = [
    "permission_prompt": "Funk",
    "idle_prompt": "default",
    "auth_success": "Glass",
    "elicitation_dialog": "Blow"
]

/// Default titles per notification type.
let notificationTypeTitles: [String: String] = [
    "permission_prompt": "Permission Needed",
    "idle_prompt": "Claude Code",
    "auth_success": "Authentication",
    "elicitation_dialog": "Input Required"
]

/// Try to parse stdin as Claude Code hook JSON. Returns populated args if successful.
func parseHookJSON(_ raw: String) -> NotificationArgs? {
    guard let data = raw.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    // Must have a "message" field to be valid hook JSON.
    guard let message = json["message"] as? String else { return nil }

    var args = NotificationArgs()
    args.message = message

    let notificationType = json["notification_type"] as? String

    // Title: JSON field > type default > global default
    if let title = json["title"] as? String, !title.isEmpty {
        args.title = title
    } else if let nt = notificationType, let typeTitle = notificationTypeTitles[nt] {
        args.title = typeTitle
    }

    // Subtitle from JSON
    if let subtitle = json["subtitle"] as? String, !subtitle.isEmpty {
        args.subtitle = subtitle
    }

    // Sound: type-specific default
    if let nt = notificationType, let typeSound = notificationTypeSounds[nt] {
        args.sound = typeSound
    }

    // Group: auto-set from notification_type so same-type notifications replace each other
    if let nt = notificationType {
        args.group = "claude-\(nt)"
    }

    return args
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var openURL: String?
    var executeCommand: String?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the notification even when the app is in the foreground.
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
                    // Try as a file path.
                    let fileURL = URL(fileURLWithPath: urlString)
                    NSWorkspace.shared.open(fileURL)
                }
            }

            if let command = userInfo["executeCommand"] as? String {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", command]
                try? process.run()
            }
        }

        completionHandler()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
    }
}

// MARK: - Main

var parsedArgs = parseArguments()

// Resolve message: CLI flags > JSON stdin > plain text stdin.
let message: String
if let msg = parsedArgs.message {
    // Explicit -message flag always wins.
    message = msg
} else if let stdinRaw = readStdin() {
    // Try parsing stdin as Claude Code hook JSON first.
    if let hookArgs = parseHookJSON(stdinRaw) {
        message = hookArgs.message!
        // Only apply JSON defaults for fields not explicitly set via CLI flags.
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
        // Plain text stdin.
        message = stdinRaw
    }
} else {
    fputs("Error: No message provided. Use -message or pipe via stdin.\n", stderr)
    exit(1)
}

// Set up the application (required for notification delivery from a .app bundle).
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No Dock icon.

let delegate = NotificationDelegate()
let center = UNUserNotificationCenter.current()
center.delegate = delegate

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
if !userInfo.isEmpty {
    content.userInfo = userInfo
}

// Use the group ID as the request identifier so that notifications in the
// same group replace each other.
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

    // Safety timeout: exit after a short delay if the delegate never fires
    // (e.g., user doesn't click the notification).
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        exit(0)
    }
}

// Run the main event loop so the app can deliver the notification and
// handle click responses.
app.run()
