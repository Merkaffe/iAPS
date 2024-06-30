import Combine
import Foundation

class Database {
    init(token: String) {
        self.token = token
    }

    private enum Config {
        static let sharePath = "/upload.php"
        static let versionPath = "/vcheck.php"
        static let retryCount = 2
        static let timeout: TimeInterval = 60
    }

    let url: URL = IAPSconfig.statURL
    let token: String

    private let service = NetworkService()
}

extension Database {
    func fetchPreferences() -> AnyPublisher<Preferences, Swift.Error> {
        let statURL = IAPSconfig.statURL
        var components = URLComponents()
        components.scheme = statURL.scheme
        components.host = statURL.host
        components.port = statURL.port
        components.path = "/download.php?token=" + token + "&section=preferences"

        var request = URLRequest(url: components.url!)
        request.allowsConstrainedNetworkAccess = true
        request.timeoutInterval = Config.timeout

        return service.run(request)
            .retry(Config.retryCount)
            .decode(type: Preferences.self, decoder: JSONCoding.decoder)
            /* .catch { error -> AnyPublisher<Preferences, Swift.Error> in
                 warning(.nightscout, "Preferences fetching error: \(error.localizedDescription) \(request)")
                 return Just(Preferences()).setFailureType(to: Swift.Error.self).eraseToAnyPublisher()
             } */
            .eraseToAnyPublisher()
    }

    func fetchSettings() -> AnyPublisher<FreeAPSSettings, Swift.Error> {
        let statURL = IAPSconfig.statURL
        var components = URLComponents()
        components.scheme = statURL.scheme
        components.host = statURL.host
        components.port = statURL.port
        components.path = "/download.php?token=" + token + "&section=preferences"

        var request = URLRequest(url: components.url!)
        request.allowsConstrainedNetworkAccess = true
        request.timeoutInterval = Config.timeout

        return service.run(request)
            .retry(Config.retryCount)
            .decode(type: FreeAPSSettings.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    func fetchProfile() -> AnyPublisher<DatabaseProfileStore, Swift.Error> {
        let statURL = IAPSconfig.statURL
        var components = URLComponents()
        components.scheme = statURL.scheme
        components.host = statURL.host
        components.port = statURL.port
        components.path = "/download.php?token=" + token + "&section=profile"

        var request = URLRequest(url: components.url!)
        request.allowsConstrainedNetworkAccess = false
        request.timeoutInterval = Config.timeout

        return service.run(request)
            .retry(Config.retryCount)
            .decode(type: DatabaseProfileStore.self, decoder: JSONCoding.decoder)
            .eraseToAnyPublisher()
    }
}
