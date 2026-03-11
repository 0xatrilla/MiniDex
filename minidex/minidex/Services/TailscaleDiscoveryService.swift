// FILE: TailscaleDiscoveryService.swift
// Purpose: Discovers Codex app-server endpoints on a tailnet and probes them before auto-connect.
// Layer: Service
// Exports: TailscaleDiscoveryConfiguration, TailscaleDiscoveryStatus, TailscaleDiscoveryService

import Foundation

struct TailscaleDiscoveryConfiguration: Sendable {
    let oauthClientID: String
    let oauthClientSecret: String
    let tailnetDNSName: String?
    let codexPort: Int
}

enum TailscaleDiscoveryStatus: Equatable {
    case idle
    case searching
    case found(String)
    case unavailable
    case failed(String)
}

enum TailscaleDiscoveryError: LocalizedError {
    case notConfigured
    case invalidOAuthResponse
    case invalidDeviceResponse
    case noReachableCodexServer

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Tailscale discovery is not configured."
        case .invalidOAuthResponse:
            return "Could not authenticate to Tailscale discovery."
        case .invalidDeviceResponse:
            return "Could not read your tailnet device list."
        case .noReachableCodexServer:
            return "No Mac on your tailnet answered like Codex."
        }
    }
}

struct TailscaleDiscoveryResult: Sendable {
    let serverURL: String
    let probedCandidates: [String]
}

final class TailscaleDiscoveryService {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 8
        self.session = URLSession(configuration: configuration)
    }

    func discoverCodexServer(configuration: TailscaleDiscoveryConfiguration) async throws -> TailscaleDiscoveryResult {
        let accessToken = try await fetchAccessToken(configuration: configuration)
        let devices = try await fetchDevices(accessToken: accessToken)
        let candidates = candidateURLs(from: devices, configuration: configuration)

        guard !candidates.isEmpty else {
            throw TailscaleDiscoveryError.noReachableCodexServer
        }

        guard let resolvedServerURL = await firstReachableCodexServerURL(in: candidates) else {
            throw TailscaleDiscoveryError.noReachableCodexServer
        }

        return TailscaleDiscoveryResult(
            serverURL: resolvedServerURL,
            probedCandidates: candidates
        )
    }
}

private extension TailscaleDiscoveryService {
    struct OAuthTokenResponse: Decodable {
        let accessToken: String

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }

    struct DeviceEnvelope: Decodable {
        let devices: [Device]?
        let machines: [Device]?
        let items: [Device]?

        var flattenedDevices: [Device] {
            if let devices, !devices.isEmpty { return devices }
            if let machines, !machines.isEmpty { return machines }
            if let items, !items.isEmpty { return items }
            return []
        }
    }

    struct Device: Decodable {
        let name: String?
        let hostname: String?
        let dnsName: String?
        let os: String?
        let addresses: [String]?
        let online: Bool?
        let isOnline: Bool?

        private enum CodingKeys: String, CodingKey {
            case name
            case hostname
            case dnsName
            case dnsNameSnake = "dns_name"
            case os
            case addresses
            case online
            case isOnline
            case isOnlineSnake = "is_online"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.hostname = try container.decodeIfPresent(String.self, forKey: .hostname)
            self.dnsName = try container.decodeIfPresent(String.self, forKey: .dnsName)
                ?? container.decodeIfPresent(String.self, forKey: .dnsNameSnake)
            self.os = try container.decodeIfPresent(String.self, forKey: .os)
            self.addresses = try container.decodeIfPresent([String].self, forKey: .addresses)
            self.online = try container.decodeIfPresent(Bool.self, forKey: .online)
            self.isOnline = try container.decodeIfPresent(Bool.self, forKey: .isOnline)
                ?? container.decodeIfPresent(Bool.self, forKey: .isOnlineSnake)
        }

        var isLikelyMac: Bool {
            let normalizedOS = (os ?? "").lowercased()
            if normalizedOS.contains("ios") || normalizedOS.contains("iphone") || normalizedOS.contains("ipad") {
                return false
            }

            return normalizedOS.contains("mac")
                || normalizedOS.contains("darwin")
                || normalizedOS.contains("osx")
        }

        var isReachable: Bool {
            online ?? isOnline ?? true
        }
    }

    func fetchAccessToken(configuration: TailscaleDiscoveryConfiguration) async throws -> String {
        guard let url = URL(string: "https://api.tailscale.com/api/v2/oauth/token") else {
            throw TailscaleDiscoveryError.invalidOAuthResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let formBody = "grant_type=client_credentials"
        request.httpBody = Data(formBody.utf8)

        let credentials = "\(configuration.oauthClientID):\(configuration.oauthClientSecret)"
        let basicToken = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(basicToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TailscaleDiscoveryError.invalidOAuthResponse
        }

        let payload = try decoder.decode(OAuthTokenResponse.self, from: data)
        let token = payload.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw TailscaleDiscoveryError.invalidOAuthResponse
        }

        return token
    }

    func fetchDevices(accessToken: String) async throws -> [Device] {
        guard let url = URL(string: "https://api.tailscale.com/api/v2/tailnet/-/devices") else {
            throw TailscaleDiscoveryError.invalidDeviceResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TailscaleDiscoveryError.invalidDeviceResponse
        }

        if let envelope = try? decoder.decode(DeviceEnvelope.self, from: data),
           !envelope.flattenedDevices.isEmpty {
            return envelope.flattenedDevices
        }

        if let devices = try? decoder.decode([Device].self, from: data),
           !devices.isEmpty {
            return devices
        }

        throw TailscaleDiscoveryError.invalidDeviceResponse
    }

    func candidateURLs(
        from devices: [Device],
        configuration: TailscaleDiscoveryConfiguration
    ) -> [String] {
        var orderedCandidates: [String] = []
        var seenCandidates: Set<String> = []

        for device in devices where device.isLikelyMac && device.isReachable {
            let hosts = hostCandidates(for: device, configuration: configuration)
            for host in hosts {
                let urlString = websocketURLString(host: host, port: configuration.codexPort)
                if seenCandidates.insert(urlString).inserted {
                    orderedCandidates.append(urlString)
                }
            }
        }

        return orderedCandidates
    }

    func hostCandidates(
        for device: Device,
        configuration: TailscaleDiscoveryConfiguration
    ) -> [String] {
        let rawHosts = [device.dnsName, device.hostname, device.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var orderedHosts: [String] = []
        var seenHosts: Set<String> = []

        for rawHost in rawHosts {
            let normalizedHost = rawHost
                .replacingOccurrences(of: ".local", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))

            if !normalizedHost.isEmpty && seenHosts.insert(normalizedHost).inserted {
                orderedHosts.append(normalizedHost)
            }

            if !normalizedHost.contains("."),
               let tailnetDNSName = configuration.tailnetDNSName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !tailnetDNSName.isEmpty {
                let fullyQualifiedHost = "\(normalizedHost).\(tailnetDNSName)"
                if seenHosts.insert(fullyQualifiedHost).inserted {
                    orderedHosts.append(fullyQualifiedHost)
                }
            }
        }

        for address in device.addresses ?? [] {
            let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAddress.isEmpty else { continue }
            if seenHosts.insert(trimmedAddress).inserted {
                orderedHosts.append(trimmedAddress)
            }
        }

        return orderedHosts
    }

    func websocketURLString(host: String, port: Int) -> String {
        if host.contains(":") {
            return "ws://[\(host)]:\(port)"
        }
        return "ws://\(host):\(port)"
    }

    func firstReachableCodexServerURL(in candidates: [String]) async -> String? {
        await withTaskGroup(of: String?.self, returning: String?.self) { taskGroup in
            for candidate in candidates.prefix(12) {
                taskGroup.addTask { [session, encoder, decoder] in
                    await Self.probeCodexServer(
                        candidate,
                        session: session,
                        encoder: encoder,
                        decoder: decoder
                    )
                }
            }

            for await result in taskGroup {
                if let result {
                    taskGroup.cancelAll()
                    return result
                }
            }

            return nil
        }
    }

    static func probeCodexServer(
        _ candidate: String,
        session: URLSession,
        encoder: JSONEncoder,
        decoder: JSONDecoder
    ) async -> String? {
        guard let url = URL(string: candidate) else {
            return nil
        }

        let requestID = UUID().uuidString
        let probeRequest = RPCMessage(
            id: .string(requestID),
            method: "initialize",
            params: .object([
                "clientInfo": .object([
                    "name": .string("minidex_ios_discovery"),
                    "title": .string("MiniDex iOS Discovery"),
                    "version": .string("1.0"),
                ]),
            ]),
            includeJSONRPC: false
        )

        do {
            return try await withTimeout(seconds: 2.5) {
                let webSocketTask = session.webSocketTask(with: url)
                webSocketTask.resume()
                defer {
                    webSocketTask.cancel(with: .goingAway, reason: nil)
                }

                let payload = try encoder.encode(probeRequest)
                guard let payloadString = String(data: payload, encoding: .utf8) else {
                    return nil
                }

                try await webSocketTask.send(.string(payloadString))

                while true {
                    let message = try await webSocketTask.receive()
                    let text: String?
                    switch message {
                    case .string(let value):
                        text = value
                    case .data(let value):
                        text = String(data: value, encoding: .utf8)
                    @unknown default:
                        text = nil
                    }

                    guard let text else { continue }
                    guard let response = try? decoder.decode(RPCMessage.self, from: Data(text.utf8)) else {
                        continue
                    }

                    guard response.id == .string(requestID), response.isResponse else {
                        continue
                    }

                    if response.result != nil {
                        return candidate
                    }

                    if let error = response.error,
                       !error.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return candidate
                    }
                }
            }
        } catch {
            return nil
        }
    }

    static func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { taskGroup in
            taskGroup.addTask {
                try await operation()
            }

            taskGroup.addTask {
                let duration = UInt64(max(0, seconds) * 1_000_000_000)
                try await Task.sleep(nanoseconds: duration)
                throw URLError(.timedOut)
            }

            guard let firstResult = try await taskGroup.next() else {
                throw URLError(.unknown)
            }

            taskGroup.cancelAll()
            return firstResult
        }
    }
}
