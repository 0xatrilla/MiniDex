// FILE: TailscaleDiscoveryService.swift
// Purpose: Discovers Codex app-server endpoints from the local Tailscale client and probes them before auto-connect.
// Layer: Service
// Exports: TailscaleDiscoveryConfiguration, TailscaleDiscoveryStatus, TailscaleDiscoveryService

import Foundation

struct TailscaleDiscoveryConfiguration: Sendable {
    let tailnetDNSName: String?
    let preferredCodexPort: Int

    var candidatePorts: [Int] {
        var orderedPorts: [Int] = []
        var seenPorts: Set<Int> = []

        for port in [preferredCodexPort, 4200, 8390, 4222] where port > 0 {
            if seenPorts.insert(port).inserted {
                orderedPorts.append(port)
            }
        }

        return orderedPorts
    }
}

enum TailscaleDiscoveryStatus: Equatable {
    case idle
    case searching
    case found(String)
    case unavailable
    case failed(String)
}

enum TailscaleDiscoveryError: LocalizedError {
    case localAPIUnavailable
    case invalidStatusResponse
    case noReachableCodexServer

    var errorDescription: String? {
        switch self {
        case .localAPIUnavailable:
            return "Tailscale is not available on this iPhone right now. Connect the phone to Tailscale or enter a host manually."
        case .invalidStatusResponse:
            return "MiniDex could not read peer details from the local Tailscale client."
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
    private static let localAPIStatusURL = URL(string: "http://100.100.100.100/localapi/v0/status")!

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 6
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    func discoverCodexServer(configuration: TailscaleDiscoveryConfiguration) async throws -> TailscaleDiscoveryResult {
        let peers = try await fetchPeers()
        let candidates = candidateURLs(from: peers, configuration: configuration)

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
    struct StatusResponse: Decodable {
        let peers: [String: Peer]

        private enum CodingKeys: String, CodingKey {
            case peers = "Peer"
            case peersLower = "peer"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.peers = try container.decodeIfPresent([String: Peer].self, forKey: .peers)
                ?? container.decodeIfPresent([String: Peer].self, forKey: .peersLower)
                ?? [:]
        }
    }

    struct Peer: Decodable {
        let hostName: String?
        let dnsName: String?
        let os: String?
        let online: Bool?
        let tailscaleIPs: [String]

        private enum CodingKeys: String, CodingKey {
            case hostName
            case hostNameUpper = "HostName"
            case dnsName
            case dnsNameUpper = "DNSName"
            case os
            case osUpper = "OS"
            case online
            case onlineUpper = "Online"
            case tailscaleIPs
            case tailscaleIPsUpper = "TailscaleIPs"
            case tailscaleIPsSnake = "tailscale_ips"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.hostName = try container.decodeIfPresent(String.self, forKey: .hostName)
                ?? container.decodeIfPresent(String.self, forKey: .hostNameUpper)
            self.dnsName = try container.decodeIfPresent(String.self, forKey: .dnsName)
                ?? container.decodeIfPresent(String.self, forKey: .dnsNameUpper)
            self.os = try container.decodeIfPresent(String.self, forKey: .os)
                ?? container.decodeIfPresent(String.self, forKey: .osUpper)
            self.online = try container.decodeIfPresent(Bool.self, forKey: .online)
                ?? container.decodeIfPresent(Bool.self, forKey: .onlineUpper)
            self.tailscaleIPs = try container.decodeIfPresent([String].self, forKey: .tailscaleIPs)
                ?? container.decodeIfPresent([String].self, forKey: .tailscaleIPsUpper)
                ?? container.decodeIfPresent([String].self, forKey: .tailscaleIPsSnake)
                ?? []
        }

        var isReachable: Bool {
            online ?? true
        }

        var isLikelyMac: Bool {
            let normalizedOS = (os ?? "").lowercased()

            if normalizedOS.isEmpty {
                return true
            }

            if normalizedOS.contains("ios")
                || normalizedOS.contains("iphone")
                || normalizedOS.contains("ipad")
                || normalizedOS.contains("android") {
                return false
            }

            return normalizedOS.contains("mac")
                || normalizedOS.contains("darwin")
                || normalizedOS.contains("osx")
        }
    }

    func fetchPeers() async throws -> [Peer] {
        var request = URLRequest(url: Self.localAPIStatusURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TailscaleDiscoveryError.invalidStatusResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw TailscaleDiscoveryError.localAPIUnavailable
            }

            let status = try decoder.decode(StatusResponse.self, from: data)
            let peers = status.peers.values.filter { $0.isReachable && $0.isLikelyMac }
            guard !peers.isEmpty else {
                throw TailscaleDiscoveryError.noReachableCodexServer
            }

            return peers
        } catch let error as TailscaleDiscoveryError {
            throw error
        } catch {
            if let urlError = error as? URLError,
               urlError.code == .cannotConnectToHost
                || urlError.code == .notConnectedToInternet
                || urlError.code == .networkConnectionLost
                || urlError.code == .timedOut {
                throw TailscaleDiscoveryError.localAPIUnavailable
            }

            throw TailscaleDiscoveryError.invalidStatusResponse
        }
    }

    func candidateURLs(
        from peers: [Peer],
        configuration: TailscaleDiscoveryConfiguration
    ) -> [String] {
        var orderedCandidates: [String] = []
        var seenCandidates: Set<String> = []

        for peer in peers {
            let hosts = hostCandidates(for: peer, configuration: configuration)
            for host in hosts {
                for port in configuration.candidatePorts {
                    let urlString = websocketURLString(host: host, port: port)
                    if seenCandidates.insert(urlString).inserted {
                        orderedCandidates.append(urlString)
                    }
                }
            }
        }

        return orderedCandidates
    }

    func hostCandidates(
        for peer: Peer,
        configuration: TailscaleDiscoveryConfiguration
    ) -> [String] {
        var orderedHosts: [String] = []
        var seenHosts: Set<String> = []

        for address in peer.tailscaleIPs.sorted(by: hostPrioritySort) {
            let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAddress.isEmpty else { continue }

            if seenHosts.insert(trimmedAddress).inserted {
                orderedHosts.append(trimmedAddress)
            }
        }

        let rawHosts = [peer.dnsName, peer.hostName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for rawHost in rawHosts {
            let normalizedHost = rawHost
                .replacingOccurrences(of: ".local", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))

            guard !normalizedHost.isEmpty else { continue }

            if seenHosts.insert(normalizedHost).inserted {
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

        return orderedHosts
    }

    func hostPrioritySort(lhs: String, rhs: String) -> Bool {
        let lhsHasIPv4 = !lhs.contains(":")
        let rhsHasIPv4 = !rhs.contains(":")

        if lhsHasIPv4 != rhsHasIPv4 {
            return lhsHasIPv4
        }

        return lhs < rhs
    }

    func websocketURLString(host: String, port: Int) -> String {
        if host.contains(":") {
            return "ws://[\(host)]:\(port)"
        }
        return "ws://\(host):\(port)"
    }

    func firstReachableCodexServerURL(in candidates: [String]) async -> String? {
        await withTaskGroup(of: String?.self, returning: String?.self) { taskGroup in
            for candidate in candidates.prefix(16) {
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
