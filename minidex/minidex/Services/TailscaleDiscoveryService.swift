// FILE: TailscaleDiscoveryService.swift
// Purpose: Discovers Codex app-server endpoints from the local Tailscale client and probes them before auto-connect.
// Layer: Service
// Exports: TailscaleDiscoveryConfiguration, TailscaleDiscoveryStatus, TailscaleDiscoveryCandidate, TailscaleDiscoveryService

import Foundation
import Network

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

enum TailscaleDiscoveryCandidateState: Sendable, Equatable {
    case queued
    case probing
    case reachable
    case unreachable
}

struct TailscaleDiscoveryCandidate: Identifiable, Sendable, Equatable {
    let id: String
    let displayName: String
    let serverURL: String
    let sourceLabel: String
    let state: TailscaleDiscoveryCandidateState

    init(
        id: String? = nil,
        displayName: String,
        serverURL: String,
        sourceLabel: String,
        state: TailscaleDiscoveryCandidateState
    ) {
        self.id = id ?? serverURL
        self.displayName = displayName
        self.serverURL = serverURL
        self.sourceLabel = sourceLabel
        self.state = state
    }

    func withState(_ state: TailscaleDiscoveryCandidateState) -> Self {
        Self(
            id: id,
            displayName: displayName,
            serverURL: serverURL,
            sourceLabel: sourceLabel,
            state: state
        )
    }
}

struct TailscaleDiscoveryResult: Sendable {
    let serverURL: String
    let probedCandidates: [TailscaleDiscoveryCandidate]
}

final class TailscaleDiscoveryService {
    private static let localAPIStatusURL = URL(string: "http://100.100.100.100/localapi/v0/status")!
    private static let maxProbedCandidates = 12

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }

        self.session = .shared
    }

    func discoverCodexServer(
        configuration: TailscaleDiscoveryConfiguration,
        onCandidateUpdate: (@Sendable (TailscaleDiscoveryCandidate) async -> Void)? = nil
    ) async throws -> TailscaleDiscoveryResult {
        let peers = try await fetchPeers()
        let candidates = candidateEndpoints(from: peers, configuration: configuration)

        guard !candidates.isEmpty else {
            throw TailscaleDiscoveryError.noReachableCodexServer
        }

        let probedCandidates = Array(candidates.prefix(Self.maxProbedCandidates))
        for candidate in probedCandidates {
            await onCandidateUpdate?(candidate.candidate)
        }

        guard let resolvedCandidate = await firstReachableCodexServer(
            in: probedCandidates,
            onCandidateUpdate: onCandidateUpdate
        ) else {
            throw TailscaleDiscoveryError.noReachableCodexServer
        }

        return TailscaleDiscoveryResult(
            serverURL: resolvedCandidate.serverURL,
            probedCandidates: probedCandidates.map(\.candidate)
        )
    }
}

private extension TailscaleDiscoveryService {
    struct CandidateHost {
        let displayName: String
        let host: String
        let sourceLabel: String
    }

    struct CandidateEndpoint: Sendable {
        let candidate: TailscaleDiscoveryCandidate
    }

    struct Peer {
        let hostName: String?
        let dnsName: String?
        let os: String?
        let online: Bool?
        let tailscaleIPs: [String]

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
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TailscaleDiscoveryError.invalidStatusResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw TailscaleDiscoveryError.localAPIUnavailable
            }

            let peers = try parsePeers(from: data).filter { $0.isReachable && $0.isLikelyMac }
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

    func parsePeers(from data: Data) throws -> [Peer] {
        guard let rootObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TailscaleDiscoveryError.invalidStatusResponse
        }

        guard let rawPeers = rootObject["Peer"] as? [String: Any]
                ?? rootObject["peer"] as? [String: Any] else {
            throw TailscaleDiscoveryError.invalidStatusResponse
        }

        return rawPeers.values.compactMap(parsePeer(from:))
    }

    func parsePeer(from rawValue: Any) -> Peer? {
        guard let dictionary = rawValue as? [String: Any] else {
            return nil
        }

        let hostInfo = dictionary["Hostinfo"] as? [String: Any]
            ?? dictionary["hostinfo"] as? [String: Any]

        let hostName = firstString(in: dictionary, keys: ["HostName", "hostName"])
            ?? firstString(in: hostInfo, keys: ["Hostname", "hostname", "HostName", "hostName"])
        let dnsName = firstString(in: dictionary, keys: ["DNSName", "dnsName"])
        let os = firstString(in: dictionary, keys: ["OS", "os"])
            ?? firstString(in: hostInfo, keys: ["OS", "os"])
        let online = firstBool(in: dictionary, keys: ["Online", "online"])
        let tailscaleIPs = firstStringArray(
            in: dictionary,
            keys: ["TailscaleIPs", "tailscaleIPs", "tailscale_ips"]
        )

        return Peer(
            hostName: hostName,
            dnsName: dnsName,
            os: os,
            online: online,
            tailscaleIPs: tailscaleIPs
        )
    }

    func firstString(in dictionary: [String: Any]?, keys: [String]) -> String? {
        guard let dictionary else { return nil }

        for key in keys {
            if let value = dictionary[key] as? String {
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedValue.isEmpty {
                    return trimmedValue
                }
            }
        }

        return nil
    }

    func firstBool(in dictionary: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = dictionary[key] as? Bool {
                return value
            }

            if let value = dictionary[key] as? NSNumber {
                return value.boolValue
            }

            if let value = dictionary[key] as? String {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "1", "yes":
                    return true
                case "false", "0", "no":
                    return false
                default:
                    continue
                }
            }
        }

        return nil
    }

    func firstStringArray(in dictionary: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            guard let values = dictionary[key] as? [Any] else { continue }

            let strings = values.compactMap { value -> String? in
                guard let stringValue = value as? String else {
                    return nil
                }

                let trimmedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmedValue.isEmpty ? nil : trimmedValue
            }

            if !strings.isEmpty {
                return strings
            }
        }

        return []
    }

    func candidateEndpoints(
        from peers: [Peer],
        configuration: TailscaleDiscoveryConfiguration
    ) -> [CandidateEndpoint] {
        var orderedCandidates: [CandidateEndpoint] = []
        var seenCandidates: Set<String> = []

        for peer in peers {
            let hosts = hostCandidates(for: peer, configuration: configuration)
            for host in hosts {
                for port in configuration.candidatePorts {
                    let urlString = websocketURLString(host: host.host, port: port)
                    if seenCandidates.insert(urlString).inserted {
                        orderedCandidates.append(
                            CandidateEndpoint(
                                candidate: TailscaleDiscoveryCandidate(
                                    displayName: host.displayName,
                                    serverURL: urlString,
                                    sourceLabel: "\(host.sourceLabel) • port \(port)",
                                    state: .queued
                                )
                            )
                        )
                    }
                }
            }
        }

        return orderedCandidates
    }

    func hostCandidates(
        for peer: Peer,
        configuration: TailscaleDiscoveryConfiguration
    ) -> [CandidateHost] {
        var orderedHosts: [CandidateHost] = []
        var seenHosts: Set<String> = []
        let displayName = peerDisplayName(peer)

        for address in peer.tailscaleIPs.sorted(by: hostPrioritySort) {
            let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAddress.isEmpty else { continue }

            if seenHosts.insert(trimmedAddress).inserted {
                orderedHosts.append(
                    CandidateHost(
                        displayName: displayName,
                        host: trimmedAddress,
                        sourceLabel: "Tailscale IP"
                    )
                )
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
                orderedHosts.append(
                    CandidateHost(
                        displayName: displayName,
                        host: normalizedHost,
                        sourceLabel: "Host"
                    )
                )
            }

            if !normalizedHost.contains("."),
               let tailnetDNSName = configuration.tailnetDNSName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !tailnetDNSName.isEmpty {
                let fullyQualifiedHost = "\(normalizedHost).\(tailnetDNSName)"
                if seenHosts.insert(fullyQualifiedHost).inserted {
                    orderedHosts.append(
                        CandidateHost(
                            displayName: displayName,
                            host: fullyQualifiedHost,
                            sourceLabel: "MagicDNS"
                        )
                    )
                }
            }
        }

        return orderedHosts
    }

    func peerDisplayName(_ peer: Peer) -> String {
        if let hostName = peer.hostName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hostName.isEmpty {
            return hostName
        }

        if let dnsName = peer.dnsName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !dnsName.isEmpty {
            return dnsName.split(separator: ".").first.map(String.init) ?? dnsName
        }

        if let address = peer.tailscaleIPs.first(where: { !$0.contains(":") }) {
            return address
        }

        return "Mac on Tailscale"
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

    func firstReachableCodexServer(
        in candidates: [CandidateEndpoint],
        onCandidateUpdate: (@Sendable (TailscaleDiscoveryCandidate) async -> Void)?
    ) async -> TailscaleDiscoveryCandidate? {
        await withTaskGroup(of: TailscaleDiscoveryCandidate?.self, returning: TailscaleDiscoveryCandidate?.self) { taskGroup in
            for candidate in candidates {
                taskGroup.addTask {
                    await Self.probeCodexServer(
                        candidate.candidate,
                        onCandidateUpdate: onCandidateUpdate
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
        _ candidate: TailscaleDiscoveryCandidate,
        onCandidateUpdate: (@Sendable (TailscaleDiscoveryCandidate) async -> Void)?
    ) async -> TailscaleDiscoveryCandidate? {
        await onCandidateUpdate?(candidate.withState(.probing))

        guard let url = URL(string: candidate.serverURL),
              let host = url.host else {
            await onCandidateUpdate?(candidate.withState(.unreachable))
            return nil
        }
        let port = UInt16(url.port ?? 80)

        let isReachable: Bool
        do {
            isReachable = try await probeOpenTCPPort(host: host, port: port)
        } catch {
            await onCandidateUpdate?(candidate.withState(.unreachable))
            return nil
        }

        let resolvedCandidate = candidate.withState(isReachable ? .reachable : .unreachable)
        await onCandidateUpdate?(resolvedCandidate)
        return isReachable ? resolvedCandidate : nil
    }

    static func probeOpenTCPPort(host: String, port: UInt16) async throws -> Bool {
        do {
            return try await withTimeout(seconds: 1.2) {
                try await withCheckedThrowingContinuation { continuation in
                    let endpointHost = NWEndpoint.Host(host)
                    guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                        continuation.resume(returning: false)
                        return
                    }
                    let connection = NWConnection(
                        host: endpointHost,
                        port: endpointPort,
                        using: .tcp
                    )

                    let lock = NSLock()
                    var hasResumed = false

                    func finish(_ result: Result<Bool, Error>) {
                        lock.lock()
                        defer { lock.unlock() }
                        guard !hasResumed else { return }
                        hasResumed = true
                        connection.stateUpdateHandler = nil
                        connection.cancel()
                        continuation.resume(with: result)
                    }

                    connection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            finish(.success(true))
                        case .failed(let error):
                            finish(.failure(error))
                        case .cancelled:
                            finish(.success(false))
                        default:
                            break
                        }
                    }

                    connection.start(queue: .global(qos: .userInitiated))
                }
            }
        } catch {
            return false
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
