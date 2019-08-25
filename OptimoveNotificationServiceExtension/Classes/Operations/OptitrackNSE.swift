//  Copyright © 2019 Optimove. All rights reserved.

import Foundation
import os.log
import OptimoveCore

/// Optitrack for Notification Service Extension protocol.
protocol OptitrackNSE {
    func report(event: OptimoveEvent, completion: @escaping () -> Void) throws
}

// TODO: Replace with the normal Optitrack component.
final class OptitrackNSEImpl {

    private let storage: OptimoveStorage
    private let repository: ConfigurationRepository

    init(storage: OptimoveStorage,
         repository: ConfigurationRepository) {
        self.storage = storage
        self.repository = repository
    }

}

extension OptitrackNSEImpl: OptitrackNSE {

    func report(event: OptimoveEvent, completion: @escaping () -> Void) throws {
        let reportEventRequest = try buildRequest(event: event)
        os_log("Sending a notification delivered event.", log: OSLog.reporter, type: .debug)
        let task = URLSession.shared.dataTask(with: reportEventRequest, completionHandler: { (data, response, error) in
            if let error = error {
                os_log("Error: %{PRIVATE}@", log: OSLog.reporter, type: .error, error.localizedDescription)
            } else {
                os_log("Sent the notification delivered event.", log: OSLog.reporter, type: .debug)
            }
            completion()
        })
        task.resume()
    }
}

private extension OptitrackNSEImpl {

    func buildRequest(event: OptimoveEvent) throws -> URLRequest {
        let configuration = try repository.getConfiguration()
        let queryItems = try buildQueryItems(
            event: event,
            config: try unwrap(configuration.events[event.name]),
            optitrack: configuration.optitrack
        )
        var reportEventUrl = try unwrap(
            URLComponents(url: configuration.optitrack.optitrackEndpoint, resolvingAgainstBaseURL: false)
        )
        reportEventUrl.queryItems = queryItems.filter { $0.value != nil }
        return URLRequest(
            url: try unwrap(reportEventUrl.url),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 5
        )
    }

    func buildQueryItems(
        event: OptimoveEvent,
        config: EventsConfig,
        optitrack: OptitrackConfig
    ) throws -> [URLQueryItem] {

        let date = Date()
        let currentUserAgent = try storage.getUserAgent()
        let userId = try storage.getCustomerID()
        let visitorId = try storage.getVisitorID()
        let initialVisitorId = try storage.getInitialVisitorId()

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "idsite", value: String(describing: optitrack.tenantID)),
            URLQueryItem(name: "rec", value: "1"),
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "_id", value: visitorId),
            URLQueryItem(name: "uid", value: userId),
            URLQueryItem(name: "lang", value: Locale.httpAcceptLanguage),
            URLQueryItem(name: "ua", value: currentUserAgent),
            URLQueryItem(name: "h", value: DateFormatter.hourDateFormatter.string(from: date)),
            URLQueryItem(name: "m", value: DateFormatter.minuteDateFormatter.string(from: date)),
            URLQueryItem(name: "s", value: DateFormatter.secondsDateFormatter.string(from: date)),
            URLQueryItem(
                name: "res",
                value: String(format: "%1.0fx%1.0f",
                              try storage.getDeviceResolutionWidth(),
                              try storage.getDeviceResolutionHeight()
                )
            ),
            URLQueryItem(name: "e_c", value: optitrack.eventCategoryName),
            URLQueryItem(name: "e_a", value: "notification_delivered"),
            URLQueryItem(
                name: "dimension\(optitrack.customDimensionIDS.eventIDCustomDimensionID)",
                value: config.id.description
            ),
            URLQueryItem(
                name: "dimension\(optitrack.customDimensionIDS.eventNameCustomDimensionID)",
                value: event.name
            )
        ]
        for (paramKey, paramConfig) in config.parameters {
            guard let paramValue = event.parameters[paramKey] else { continue }
            queryItems.append(
                URLQueryItem(name: "dimension\(paramConfig.optiTrackDimensionId)", value: "\(paramValue)")
            )
        }
        return queryItems + queryItemsWithPluginFlags(from: initialVisitorId)
    }

    func queryItemsWithPluginFlags(from visitorId: String) -> [URLQueryItem] {
        let pluginFlags = ["fla", "java", "dir", "qt", "realp", "pdf", "wma", "gears"]
        let pluginValues = visitorId.splitedBy(length: 2).map { Int($0, radix: 16)!/2 }.map { $0.description }
        return pluginFlags.enumerated().map({ (arg) -> URLQueryItem in
            let pluginFlag = pluginFlags[arg.offset]
            let pluginValue = pluginValues[arg.offset]
            return URLQueryItem(name: pluginFlag, value: pluginValue)
        })
    }

}

extension OSLog {
    static let optitrack = OSLog(subsystem: subsystem, category: "OptitrackNSE")
}
