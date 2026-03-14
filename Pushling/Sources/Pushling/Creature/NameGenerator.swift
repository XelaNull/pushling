// NameGenerator.swift — Deterministic 2-syllable name from git identity
// SHA256(git_user_email + machine_UUID) -> 144 possible names.
// Pure function, no side effects, testable.
//
// First syllable (12): Pip, Nub, Zep, Tik, Mox, Glo, Rux, Bim, Quo, Fen, Dax, Yol
// Second syllable (12): -o, -i, -us, -el, -a, -ix, -on, -y, -er, -um, -is, -ot
//
// Examples: Pipo, Zepus, Moxa, Ruxon, Fenum, Daxis

import Foundation
import CommonCrypto

// MARK: - Name Generator

enum NameGenerator {

    // MARK: - Syllable Tables

    /// 12 first syllables.
    static let firstSyllables = [
        "Pip", "Nub", "Zep", "Tik", "Mox", "Glo",
        "Rux", "Bim", "Quo", "Fen", "Dax", "Yol"
    ]

    /// 12 second syllables (suffixes).
    static let secondSyllables = [
        "o", "i", "us", "el", "a", "ix",
        "on", "y", "er", "um", "is", "ot"
    ]

    /// Total possible names: 12 × 12 = 144.
    static var totalNames: Int {
        firstSyllables.count * secondSyllables.count
    }

    // MARK: - Generation

    /// Generate a deterministic name from git user.email + machine UUID.
    /// Same email + same machine = always the same name.
    ///
    /// - Parameters:
    ///   - email: The git user.email (or "unknown@pushling" as fallback).
    ///   - machineUUID: The machine's hardware UUID.
    /// - Returns: A 2-syllable name (e.g., "Zepus").
    static func generate(email: String, machineUUID: String) -> String {
        let input = email + machineUUID
        let hash = sha256(input)

        guard hash.count >= 2 else {
            // Fallback — should never happen with SHA256
            return firstSyllables[0] + secondSyllables[0]
        }

        let firstIndex = Int(hash[0]) % firstSyllables.count
        let secondIndex = Int(hash[1]) % secondSyllables.count

        let first = firstSyllables[firstIndex]
        let second = secondSyllables[secondIndex]

        return first + second
    }

    /// Generate a name using the system's git email and machine UUID.
    /// Convenience method that discovers both values automatically.
    static func generateFromSystem() -> String {
        let email = getGitEmail()
        let uuid = getMachineUUID()
        return generate(email: email, machineUUID: uuid)
    }

    // MARK: - SHA256

    /// Compute SHA256 hash of a string, returning raw bytes.
    private static func sha256(_ string: String) -> [UInt8] {
        guard let data = string.data(using: .utf8) else { return [] }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash
    }

    // MARK: - System Discovery

    /// Get the global git user.email.
    private static func getGitEmail() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["config", "--global", "user.email"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "unknown@pushling"
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let email = (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return email.isEmpty ? "unknown@pushling" : email
    }

    /// Get the machine's hardware UUID.
    /// Uses `sysctl hw.uuid` as the primary method.
    private static func getMachineUUID() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["-n", "kern.uuid"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return fallbackUUID()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let uuid = (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return uuid.isEmpty ? fallbackUUID() : uuid
    }

    /// Fallback UUID from IOPlatformExpertDevice via system_profiler.
    private static func fallbackUUID() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-rd1", "-c", "IOPlatformExpertDevice"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "unknown-machine"
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Parse IOPlatformUUID from ioreg output
        if let range = output.range(of: "IOPlatformUUID") {
            let after = output[range.upperBound...]
            // Find the UUID string (format: "XXXXXXXX-XXXX-...")
            if let quoteStart = after.firstIndex(of: "\""),
               let quoteEnd = after[after.index(after: quoteStart)...]
                   .firstIndex(of: "\"") {
                let start = after.index(after: quoteStart)
                let uuid = String(after[start..<quoteEnd])
                if !uuid.isEmpty { return uuid }
            }
        }

        return "unknown-machine"
    }

    // MARK: - Validation

    /// Validate that a name could have been generated by this system.
    static func isValidGeneratedName(_ name: String) -> Bool {
        for first in firstSyllables {
            if name.hasPrefix(first) {
                let suffix = String(name.dropFirst(first.count))
                if secondSyllables.contains(suffix) {
                    return true
                }
            }
        }
        return false
    }

    /// Get all possible generated names (for debugging/display).
    static func allPossibleNames() -> [String] {
        var names: [String] = []
        for first in firstSyllables {
            for second in secondSyllables {
                names.append(first + second)
            }
        }
        return names
    }
}
