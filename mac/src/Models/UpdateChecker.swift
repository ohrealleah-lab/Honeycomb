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

// Manual-only: checks GitHub's latest release against the running app version. There is
// deliberately no automatic/background check and no auto-download/apply — this only ever
// runs when the player clicks "Check for Updates" in the About window, and the result is
// just a link to the release page for them to download and run the installer themselves.
@Observable
public class UpdateChecker {
    public static let shared = UpdateChecker()

    // Drives the inline "Check for Updates" UI on the About page.
    public var manualCheckState: ManualUpdateCheckState = .idle

    private static let repo = "ohrealleah-lab/Honeycomb"

    private init() {}

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    public func checkNow() {
        manualCheckState = .checking
        fetchLatestRelease { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let outcome):
                self.manualCheckState = outcome.isNewer ? .newerAvailable(outcome) : .upToDate
            case .failure:
                self.manualCheckState = .failed
            }
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
