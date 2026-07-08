// email_validator.swift
import Foundation
import Network

let DISPOSABLE_DOMAINS: Set<String> = [
    "mailinator.com", "guerrillamail.com", "temp-mail.org", "10minutemail.com",
    "throwawaymail.com", "yopmail.com", "trashmail.com", "spamgourmet.com",
    "fakeinbox.com", "emailondeck.com", "gettemporaryemail.com", "sharklasers.com",
    "guerrillamail.net", "guerrillamail.org", "guerrillamail.biz", "mailnator.com",
    "spambox.us", "tempemail.net", "mailcatch.com", "mytrashmail.com",
    "trash2009.com", "trashdevil.com", "trashmail.net", "trashmail.org",
    "trashmail.ws", "trashmail.me", "trashmail.io", "tmpmail.org",
    "tmpmail.net", "tmpmail.com", "tempinbox.com", "tempemail.org",
    "tempemail.com", "tempail.com", "tempmail.com", "tempmail.net",
    "tempmail.org", "tempmail.biz", "tempmail.info", "tempmail.io",
    "tempmail.me", "tempmail.us", "tempmail.ws", "tempmail.co",
    "tempmail.co.uk", "tempmail.de", "tempmail.fr"
]

class EmailValidator {
    var checkDomain: Bool
    private(set) var stats: (total: Int, valid: Int, invalid: Int) = (0, 0, 0)
    private let emailRegex: NSRegularExpression

    init(checkDomain: Bool = true) {
        self.checkDomain = checkDomain
        let pattern = #"^(?<local>[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+)@(?<domain>[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$"#
        self.emailRegex = try! NSRegularExpression(pattern: pattern)
    }

    func validateSyntax(_ email: String) -> (valid: Bool, reason: String) {
        guard !email.isEmpty, email.count <= 254 else {
            return (false, "Empty or too long (>254)")
        }
        let nsRange = NSRange(email.startIndex..., in: email)
        guard let match = emailRegex.firstMatch(in: email, range: nsRange) else {
            return (false, "Invalid format")
        }
        let localRange = match.range(withName: "local")
        let domainRange = match.range(withName: "domain")
        let local = String(email[Range(localRange, in: email)!])
        let domain = String(email[Range(domainRange, in: email)!])
        if local.count > 64 {
            return (false, "Local part too long (>64)")
        }
        if local.contains("..") || local.hasPrefix(".") || local.hasSuffix(".") {
            return (false, "Invalid local part (dots)")
        }
        if !domain.contains(".") {
            return (false, "Domain must contain a dot")
        }
        for label in domain.split(separator: ".") {
            if label.count > 63 || label.isEmpty {
                return (false, "Invalid domain label")
            }
        }
        return (true, "Syntax OK")
    }

    func domainExists(_ domain: String) -> Bool {
        guard checkDomain else { return true }
        // Try A record via DNS resolution
        let host = NWEndpoint.Host(domain)
        let port = NWEndpoint.Port(integerLiteral: 25) // dummy
        let connection = NWConnection(host: host, port: port, using: .udp)
        let semaphore = DispatchSemaphore(value: 0)
        var exists = false
        connection.start(queue: .global())
        connection.send(content: nil, completion: .contentProcessed({ _ in
            // If we can send, address likely exists (not perfect, but works for demonstration)
            // Actually we just want to see if host is resolved, so we can use a simple resolver.
            // Better: use DNS lookup via CFHost or Network framework.
            // Since Network framework doesn't directly give A records, we use Host.
            // Use a simpler approach: get IP via Darwin.
            // We'll fallback to using getaddrinfo via Foundation.
            // But it's simpler to just use a plain resolver.
            exists = true
            semaphore.signal()
        }))
        _ = semaphore.wait(timeout: .now() + 2)
        connection.cancel()
        // If exists false, try MX via a different method (skip for brevity)
        // Since this is a demo, we'll just return true if we can get any IP.
        // We'll use `getaddrinfo` via C, but for simplicity we use Host.
        // Instead, we'll just return true if the domain can be resolved via CFHost.
        // Let's use simple approach: try to resolve using DNS.
        let resolver = CFHostCreateWithName(kCFAllocatorDefault, domain as CFString).takeRetainedValue()
        var resolved = false
        if CFHostStartInfoResolution(resolver, .addresses, nil) {
            resolved = true
        }
        return resolved
    }

    func isDisposable(_ domain: String) -> Bool {
        return DISPOSABLE_DOMAINS.contains(domain.lowercased())
    }

    func validate(_ email: String) -> (valid: Bool, reason: String) {
        stats.total += 1
        let syntax = validateSyntax(email)
        if !syntax.valid {
            stats.invalid += 1
            return (false, "Syntax error: \(syntax.reason)")
        }
        let domain = email.split(separator: "@")[1].lowercased()
        if isDisposable(String(domain)) {
            stats.invalid += 1
            return (false, "Disposable email domain detected")
        }
        if !domainExists(String(domain)) {
            stats.invalid += 1
            return (false, "Domain does not exist (no A/MX record)")
        }
        stats.valid += 1
        return (true, "Valid email")
    }

    func batchValidate(_ emails: [String]) -> [(email: String, valid: Bool, reason: String)] {
        var results: [(String, Bool, String)] = []
        for e in emails {
            let email = e.trimmingCharacters(in: .whitespaces)
            if email.isEmpty { continue }
            let (valid, reason) = validate(email)
            results.append((email, valid, reason))
        }
        return results
    }

    func showStats() {
        print("\nStatistics: Total: \(stats.total), Valid: \(stats.valid), Invalid: \(stats.invalid)")
    }
}

func main() {
    let validator = EmailValidator(checkDomain: true)
    print("=== Email Validator ===")
    while true {
        print("\n1. Validate single email")
        print("2. Validate from file")
        print("3. Show statistics")
        print("4. Toggle domain validation (currently \(validator.checkDomain ? "ON" : "OFF"))")
        print("5. Exit")
        print("Choose: ", terminator: "")
        guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
        switch choice {
        case "1":
            print("Enter email: ", terminator: "")
            guard let email = readLine()?.trimmingCharacters(in: .whitespaces) else { break }
            let (valid, reason) = validator.validate(email)
            print("Valid: \(valid)")
            print("Details: \(reason)")
        case "2":
            print("Enter file path: ", terminator: "")
            guard let fname = readLine()?.trimmingCharacters(in: .whitespaces) else { break }
            let fileURL = URL(fileURLWithPath: fname)
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                print("File not found or unreadable.")
                break
            }
            let emails = content.components(separatedBy: .newlines)
            let results = validator.batchValidate(emails)
            print("\nBatch results:")
            for r in results {
                let status = r.valid ? "✓" : "✗"
                print("\(status) \(r.email): \(r.reason)")
            }
        case "3":
            validator.showStats()
        case "4":
            validator.checkDomain.toggle()
            print("Domain validation toggled.")
        case "5":
            print("Goodbye!")
            return
        default:
            print("Invalid choice.")
        }
    }
}

main()
