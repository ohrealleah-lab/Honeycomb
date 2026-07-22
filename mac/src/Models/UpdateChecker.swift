import Foundation
import Observation

public struct UpdateCheckOutcome: Equatable {
    public let latestVersion: String
    public let releaseURL: URL
    public let isNewer: Bool
}

public enum ManualUpdateCheckState: Equatable {
    case idle
    case checking
    case upToDate
    case failed
    case newerAvailable(UpdateCheckOutcome)
}

// Checks GitHub Releases for a newer Honeycomb build. Two entry points:
// checkIfDue() (launch-time, respects the 30-day cadence and the disabled flag)
// and checkNow() (the About page's manual "Check for Updates" button, which
// always hits the network live regardless of either). Both funnel through the
// same fetch/compare logic; only how the result is surfaced differs.
@Observable
public class UpdateChecker {
    public static let shared = UpdateChecker()

    // Set when the automatic launch-time check finds a newer version — AppRouterView
    // presents an alert while this is non-nil and clears it once the user responds.
    public var pendingAutomaticPrompt: UpdateCheckOutcome?

    // Drives the inline "Check for Updates" UI on the About page.
    public var manualCheckState: ManualUpdateCheckState = .idle

    private static let repo = "ohrealleah-lab/Honeycomb"
    private static let checkIntervalDays: Double = 30

    private let disabledKey = "update_checks_disabled"
    private let disabledAtVersionKey = "update_checks_disabled_at_version"
    private let lastCheckKey = "update_last_check_date"

    private init() {
        resetDisabledFlagIfNewerVersionInstalled()
    }

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    // MARK: - Automatic (launch-time) check

    public func checkIfDue() {
        resetDisabledFlagIfNewerVersionInstalled()

        guard !UserDefaults.standard.bool(forKey: disabledKey) else { return }

        if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
            let daysSince = Date().timeIntervalSince(lastCheck) / 86400
            guard daysSince >= Self.checkIntervalDays else { return }
        }

        fetchLatestRelease { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let outcome):
                UserDefaults.standard.set(Date(), forKey: self.lastCheckKey)
                if outcome.isNewer {
                    self.pendingAutomaticPrompt = outcome
                }
            case .failure:
                // Offline or GitHub unreachable — stay silent and just retry next
                // launch (deliberately not updating lastCheckKey here).
                break
            }
        }
    }

    // MARK: - Manual check (About page)

    public func checkNow() {
        manualCheckState = .checking
        fetchLatestRelease { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let outcome):
                UserDefaults.standard.set(Date(), forKey: self.lastCheckKey)
                self.manualCheckState = outcome.isNewer ? .newerAvailable(outcome) : .upToDate
            case .failure:
                self.manualCheckState = .failed
            }
        }
    }

    // "Don't Ask Again" from either the automatic prompt or the About page.
    public func declineUpdate() {
        UserDefaults.standard.set(true, forKey: disabledKey)
        UserDefaults.standard.set(currentVersion, forKey: disabledAtVersionKey)
        pendingAutomaticPrompt = nil
        if case .newerAvailable = manualCheckState {
            manualCheckState = .idle
        }
    }

    public func dismissAutomaticPrompt() {
        pendingAutomaticPrompt = nil
    }

    // MARK: - Internals

    private func resetDisabledFlagIfNewerVersionInstalled() {
        guard UserDefaults.standard.bool(forKey: disabledKey),
              let disabledAtVersion = UserDefaults.standard.string(forKey: disabledAtVersionKey) else { return }
        if Self.isVersion(currentVersion, newerThan: disabledAtVersion) {
            UserDefaults.standard.set(false, forKey: disabledKey)
            UserDefaults.standard.removeObject(forKey: disabledAtVersionKey)
        }
    }

    private func fetchLatestRelease(completion: @escaping (Result<UpdateCheckOutcome, Error>) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Honeycomb-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let currentVersion = self.currentVersion
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data,
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURLString = json["html_url"] as? String,
                  let htmlURL = URL(string: htmlURLString) else {
                DispatchQueue.main.async { completion(.failure(URLError(.badServerResponse))) }
                return
            }
            let outcome = UpdateCheckOutcome(
                latestVersion: tagName,
                releaseURL: htmlURL,
                isNewer: UpdateChecker.isVersion(tagName, newerThan: currentVersion)
            )
            DispatchQueue.main.async { completion(.success(outcome)) }
        }.resume()
    }

    // Compares dot-separated numeric version strings component by component
    // (e.g. "0.9.10" > "0.9.6"), tolerant of a leading "v"/"V" and missing
    // trailing components (shorter strings are padded with 0s).
    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        func components(_ s: String) -> [Int] {
            var s = s
            if s.first == "v" || s.first == "V" { s.removeFirst() }
            return s.split(separator: ".").map { Int($0) ?? 0 }
        }
        let a = components(lhs)
        let b = components(rhs)
        for i in 0..<max(a.count, b.count) {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }
}
