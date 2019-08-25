//  Copyright © 2019 Optimove. All rights reserved.

import OptimoveCore

final class GlobalConfigurationDownloader: AsyncOperation {

    private let networking: RemoteConfigurationNetworking
    private let repository: ConfigurationRepository

    init(networking: RemoteConfigurationNetworking,
         repository: ConfigurationRepository) {
        self.networking = networking
        self.repository = repository
    }

    override func main() {
        guard !self.isCancelled else { return }
        state = .executing
        networking.getGlobalConfiguration { result in
            do {
                let global = try result.get()
                try self.repository.saveGlobal(global)
            } catch {
                Logger.error(error.localizedDescription)
            }
            self.state = .finished
        }
    }
}
