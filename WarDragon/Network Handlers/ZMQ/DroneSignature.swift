//
//  DroneSignature.swift
//  WarDragon
//
//  Created by Luke on 12/4/24.
//

import Foundation
import CoreLocation

struct DroneSignature: Hashable {
    // Core identification
    let primaryId: IdInfo
    let secondaryId: IdInfo?  // For dual-broadcast correlation
    let operatorId: String?
    let sessionId: String?
    
    // Physical characteristics
    let position: PositionInfo
    let movement: MovementVector
    let heightInfo: HeightInfo
    
    // Signal characteristics
    let transmissionInfo: TransmissionInfo
    let broadcastPattern: BroadcastPattern
    
    // Time components
    let timestamp: TimeInterval
    let firstSeen: TimeInterval
    let messageInterval: TimeInterval?
    
    struct IdInfo: Hashable {
        let id: String
        let type: IdType
        let protocolVersion: String
        let uaType: UAType
        
        enum IdType: String, Hashable {
            case serialNumber = "Serial Number (ANSI/CTA-2063-A)"
            case caaRegistration = "CAA Registration ID"
            case utmAssigned = "UTM (USS) Assigned ID"
            case sessionId = "Specific Session ID"
            case unknown = "Unknown"
        }
        
        enum UAType: String, Hashable {
            case none = "None"
            case aeroplane = "Aeroplane"
            case helicopter = "Helicopter/Multirotor"
            case gyroplane = "Gyroplane"
            case hybridLift = "Hybrid Lift"
            case ornithopter = "Ornithopter"
            case glider = "Glider"
            case kite = "Kite"
            case freeballoon = "Free Balloon"
            case captive = "Captive Balloon"
            case airship = "Airship"
            case freeFall = "Free Fall/Parachute"
            case rocket = "Rocket"
            case tethered = "Tethered Powered Aircraft"
            case groundObstacle = "Ground Obstacle"
            case other = "Other"
        }
    }
    
    struct PositionInfo: Hashable {
        let coordinate: CLLocationCoordinate2D
        let altitude: Double
        let altitudeReference: AltitudeReference
        let lastKnownGoodPosition: CLLocationCoordinate2D?
        let operatorLocation: CLLocationCoordinate2D?
        let horizontalAccuracy: Double?
        let verticalAccuracy: Double?
        let timestamp: TimeInterval
        
        enum AltitudeReference: String {
            case takeoff = "Takeoff Location"
            case ground = "Ground Level"
            case wgs84 = "WGS84"
        }
        
        static func == (lhs: PositionInfo, rhs: PositionInfo) -> Bool {
            return lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.altitude == rhs.altitude &&
            lhs.altitudeReference == rhs.altitudeReference &&
            lhs.timestamp == rhs.timestamp &&
            ((lhs.lastKnownGoodPosition == nil && rhs.lastKnownGoodPosition == nil) ||
             (lhs.lastKnownGoodPosition?.latitude == rhs.lastKnownGoodPosition?.latitude &&
              lhs.lastKnownGoodPosition?.longitude == rhs.lastKnownGoodPosition?.longitude)) &&
            ((lhs.operatorLocation == nil && rhs.operatorLocation == nil) ||
             (lhs.operatorLocation?.latitude == rhs.operatorLocation?.latitude &&
              lhs.operatorLocation?.longitude == rhs.operatorLocation?.longitude)) &&
            lhs.horizontalAccuracy == rhs.horizontalAccuracy &&
            lhs.verticalAccuracy == rhs.verticalAccuracy
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(coordinate.latitude)
            hasher.combine(coordinate.longitude)
            hasher.combine(altitude)
            hasher.combine(altitudeReference)
            hasher.combine(timestamp)
            if let lastKnown = lastKnownGoodPosition {
                hasher.combine(lastKnown.latitude)
                hasher.combine(lastKnown.longitude)
            }
            if let opLocation = operatorLocation {
                hasher.combine(opLocation.latitude)
                hasher.combine(opLocation.longitude)
            }
            hasher.combine(horizontalAccuracy)
            hasher.combine(verticalAccuracy)
        }
    }
    
    struct MovementVector: Hashable {
        let groundSpeed: Double
        let verticalSpeed: Double
        let heading: Double
        let climbRate: Double?
        let turnRate: Double?
        let flightPath: [CLLocationCoordinate2D]?
        let timestamp: TimeInterval
        
        static func == (lhs: MovementVector, rhs: MovementVector) -> Bool {
            return lhs.groundSpeed == rhs.groundSpeed &&
            lhs.verticalSpeed == rhs.verticalSpeed &&
            lhs.heading == rhs.heading &&
            lhs.climbRate == rhs.climbRate &&
            lhs.turnRate == rhs.turnRate &&
            lhs.timestamp == rhs.timestamp &&
            compareFlightPaths(lhs.flightPath, rhs.flightPath)
        }
        
        private static func compareFlightPaths(_ path1: [CLLocationCoordinate2D]?, _ path2: [CLLocationCoordinate2D]?) -> Bool {
            guard let p1 = path1, let p2 = path2 else {
                return path1 == nil && path2 == nil
            }
            guard p1.count == p2.count else { return false }
            return zip(p1, p2).allSatisfy { coord1, coord2 in
                coord1.latitude == coord2.latitude && coord1.longitude == coord2.longitude
            }
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(groundSpeed)
            hasher.combine(verticalSpeed)
            hasher.combine(heading)
            hasher.combine(climbRate)
            hasher.combine(turnRate)
            hasher.combine(timestamp)
            if let path = flightPath {
                for coord in path {
                    hasher.combine(coord.latitude)
                    hasher.combine(coord.longitude)
                }
            }
        }
    }
    
    struct HeightInfo: Hashable {
        let heightAboveGround: Double
        let heightAboveTakeoff: Double?
        let referenceType: HeightReferenceType
        let horizontalAccuracy: Double?
        let verticalAccuracy: Double?
        let consistencyScore: Double
        let lastKnownGoodHeight: Double?
        let timestamp: TimeInterval
        
        enum HeightReferenceType: String {
            case ground = "Above Ground Level"
            case takeoff = "Above Takeoff"
            case pressureAltitude = "Pressure Altitude"
            case wgs84 = "WGS84"
        }
    }
    
    struct TransmissionInfo: Hashable {
        let transmissionType: TransmissionType
        let signalStrength: Double?
        let frequency: Double?
        let protocolType: ProtocolType
        let messageTypes: Set<MessageType>
        let timestamp: TimeInterval
        
        enum TransmissionType: String {
            case ble = "Bluetooth LE"
            case wifi = "WiFi"
            case esp32 = "ESP32"
            case unknown = "Unknown"
        }
        
        enum ProtocolType: String {
            case openDroneID = "Open Drone ID"
            case legacyRemoteID = "Legacy Remote ID"
            case astmF3411 = "ASTM F3411"
            case custom = "Custom"
        }
        
        enum MessageType: String, Hashable {
            case basicId = "Basic ID"
            case location = "Location"
            case authentication = "Authentication"
            case selfId = "Self ID"
            case system = "System"
            case operatorId = "Operator ID"
        }
    }
    
    struct BroadcastPattern: Hashable {
        let messageSequence: [TransmissionInfo.MessageType]
        let intervalPattern: [TimeInterval]
        let consistency: Double
        let startTime: TimeInterval
        let lastUpdate: TimeInterval
    }
}

class DroneSignatureGenerator {
    private struct Thresholds {
        static let horizontalPositionMeters: Double = 10.0
        static let verticalPositionMeters: Double = 5.0
        static let speedDeltaMS: Double = 2.0
        static let headingDeltaDegrees: Double = 15.0
        static let timeWindowSeconds: Double = 2.0
        static let operatorDistanceMeters: Double = 50.0
        static let heightConsistencyThreshold: Double = 0.8
        static let patternMatchThreshold: Double = 0.7
        static let signalStrengthDelta: Double = 10.0
        static let messageIntervalDelta: Double = 0.5
    }
    
    private var signatureCache: [String: DroneTrackingInfo] = [:]
    private let cachePruneInterval: TimeInterval = 300
    private var lastPruneTime: TimeInterval = 0
    
    struct DroneTrackingInfo {
        var signatures: [DroneSignature]
        var lastUpdate: TimeInterval
        var confidenceScore: Double
        var matchHistory: [SignatureMatch]
        var flightPath: [CLLocationCoordinate2D]
        var heightProfile: [Double]
    }
    
    struct SignatureMatch {
        let timestamp: TimeInterval
        let matchStrength: Double
        let matchedFields: Set<MatchField>
        let confidence: Double
        
        enum MatchField: String {
            case primaryId
            case secondaryId
            case operatorLocation
            case position
            case movement
            case heightPattern
            case broadcastPattern
            case signalCharacteristics
        }
    }
    
    private func calculateMatchConfidence(_ matchedFields: Set<SignatureMatch.MatchField>) -> Double {
        let weights: [SignatureMatch.MatchField: Double] = [
            .primaryId: 0.3,
            .secondaryId: 0.1,
            .operatorLocation: 0.1,
            .position: 0.15,
            .movement: 0.15,
            .heightPattern: 0.1,
            .broadcastPattern: 0.1,
            .signalCharacteristics: 0.1
        ]
        
        return matchedFields.reduce(0.0) { sum, field in
            sum + (weights[field] ?? 0.0)
        }
    }
    
    private func updateMatchHistory(_ id: String, _ match: SignatureMatch) {
        var info = signatureCache[id]
        info?.matchHistory.append(match)
        
        // Keep only recent history
        if info?.matchHistory.count ?? 0 > 100 {
            info?.matchHistory.removeFirst()
        }
        
        signatureCache[id] = info
    }
    
    func createSignature(from message: [String: Any]) -> DroneSignature {
        pruneCache()
        
        let now = Date().timeIntervalSince1970
        let primaryId = extractPrimaryId(message)
        let cacheInfo = signatureCache[primaryId.id]
        
        let signature = DroneSignature(
            primaryId: primaryId,
            secondaryId: extractSecondaryId(message),
            operatorId: message["operatorId"] as? String,
            sessionId: message["sessionId"] as? String,
            position: extractPositionInfo(message),
            movement: extractMovementVector(message, previousPath: cacheInfo?.flightPath),
            heightInfo: extractHeightInfo(message, previousHeights: cacheInfo?.heightProfile),
            transmissionInfo: extractTransmissionInfo(message),
            broadcastPattern: extractBroadcastPattern(message, droneId: primaryId.id, timestamp: now),
            timestamp: now,
            firstSeen: cacheInfo?.signatures.first?.timestamp ?? now,
            messageInterval: calculateMessageInterval(forId: primaryId.id)
        )
        
        updateSignatureCache(signature)
        return signature
    }
    
    func matchSignatures(_ current: DroneSignature, _ candidate: DroneSignature) -> Double {
        var matchStrength = 0.0
        var matchedFields = Set<SignatureMatch.MatchField>()
        
        // Position and movement matching (40%)
        if let positionScore = matchPositionAndMovement(current, candidate) {
            matchStrength += positionScore * 0.4
            matchedFields.insert(.position)
            matchedFields.insert(.movement)
        }
        
        // Height pattern matching (30%)
        if let heightScore = matchHeightProfile(current, candidate) {
            matchStrength += heightScore * 0.3
            matchedFields.insert(.heightPattern)
        }
        
        // Broadcast characteristics (30%)
        if let broadcastScore = matchBroadcastCharacteristics(current, candidate) {
            matchStrength += broadcastScore * 0.3
            matchedFields.insert(.broadcastPattern)
            matchedFields.insert(.signalCharacteristics)
        }
        
        // Add operator location match if available
        if let operatorScore = matchOperatorLocations(current, candidate) {
            matchStrength = (matchStrength * 0.8) + (operatorScore * 0.2)
            matchedFields.insert(.operatorLocation)
        }
        
        // Record match history
        let confidence = calculateMatchConfidence(matchedFields)
        updateMatchHistory(
            current.primaryId.id,
            SignatureMatch(
                timestamp: current.timestamp,
                matchStrength: matchStrength,
                matchedFields: matchedFields,
                confidence: confidence
            )
        )
        
        return matchStrength
    }
    
    private func matchOperatorLocations(_ current: DroneSignature, _ candidate: DroneSignature) -> Double? {
        guard let currentOp = current.position.operatorLocation,
              let candidateOp = candidate.position.operatorLocation else {
            return nil
        }
        
        let location1 = CLLocation(latitude: currentOp.latitude, longitude: currentOp.longitude)
        let location2 = CLLocation(latitude: candidateOp.latitude, longitude: candidateOp.longitude)
        
        let distance = location1.distance(from: location2)
        return max(0, 1 - (distance / Thresholds.operatorDistanceMeters))
    }
    
    private func matchPositionAndMovement(_ current: DroneSignature, _ candidate: DroneSignature) -> Double? {
        // Skip if either position is invalid (0,0)
        if current.position.coordinate.latitude == 0 || current.position.coordinate.longitude == 0 ||
            candidate.position.coordinate.latitude == 0 || candidate.position.coordinate.longitude == 0 {
            return nil
        }
        
        let currentLocation = CLLocation(latitude: current.position.coordinate.latitude,
                                         longitude: current.position.coordinate.longitude)
        let candidateLocation = CLLocation(latitude: candidate.position.coordinate.latitude,
                                           longitude: candidate.position.coordinate.longitude)
        
        let distance = currentLocation.distance(from: candidateLocation)
        let speedDelta = abs(current.movement.groundSpeed - candidate.movement.groundSpeed)
        let vspeedDelta = abs(current.movement.verticalSpeed - candidate.movement.verticalSpeed)
        
        // Normalize scores
        let positionScore = max(0, 1 - (distance / Thresholds.horizontalPositionMeters))
        let speedScore = max(0, 1 - (speedDelta / Thresholds.speedDeltaMS))
        let vspeedScore = max(0, 1 - (vspeedDelta / Thresholds.speedDeltaMS))
        
        // Calculate heading difference with wraparound
        var headingDelta = abs(current.movement.heading - candidate.movement.heading)
        if headingDelta > 180 {
            headingDelta = 360 - headingDelta
        }
        let headingScore = max(0, 1 - (headingDelta / Thresholds.headingDeltaDegrees))
        
        return (positionScore + speedScore + vspeedScore + headingScore) / 4.0
    }
    
    private func matchHeightProfile(_ current: DroneSignature, _ candidate: DroneSignature) -> Double? {
        guard let currentHistory = signatureCache[current.primaryId.id]?.heightProfile,
              let candidateHistory = signatureCache[candidate.primaryId.id]?.heightProfile,
              !currentHistory.isEmpty && !candidateHistory.isEmpty else {
            return nil
        }
        
        let heightDelta = abs(current.heightInfo.heightAboveGround - candidate.heightInfo.heightAboveGround)
        let heightScore = max(0, 1 - (heightDelta / Thresholds.verticalPositionMeters))
        
        let consistencyDelta = abs(current.heightInfo.consistencyScore - candidate.heightInfo.consistencyScore)
        let consistencyScore = max(0, 1 - consistencyDelta)
        
        // Compare height profiles if we have enough data
        var profileScore = 0.0
        if currentHistory.count >= 3 && candidateHistory.count >= 3 {
            profileScore = compareHeightProfiles(currentHistory, candidateHistory)
        }
        
        return (heightScore + consistencyScore + profileScore) / 3.0
    }
    
    private func compareHeightProfiles(_ profile1: [Double], _ profile2: [Double]) -> Double {
        // Calculate trend similarity
        let trends1 = zip(profile1, profile1.dropFirst()).map { $1 - $0 }
        let trends2 = zip(profile2, profile2.dropFirst()).map { $1 - $0 }
        
        let trendMatches = zip(trends1, trends2).map { t1, t2 -> Double in
            if (t1 > 0 && t2 > 0) || (t1 < 0 && t2 < 0) || (abs(t1) < 0.1 && abs(t2) < 0.1) {
                return 1.0
            }
            return 0.0
        }
        
        return trendMatches.reduce(0.0, +) / Double(trendMatches.count)
    }
    
    private func matchBroadcastCharacteristics(_ current: DroneSignature, _ candidate: DroneSignature) -> Double? {
        let typeScore = current.transmissionInfo.transmissionType == candidate.transmissionInfo.transmissionType ? 1.0 : 0.0
        
        // Compare signal strengths if available
        var signalScore = 1.0
        if let signal1 = current.transmissionInfo.signalStrength,
           let signal2 = candidate.transmissionInfo.signalStrength {
            let delta = abs(signal1 - signal2)
            signalScore = max(0, 1 - (delta / Thresholds.signalStrengthDelta))
        }
        
        // Compare message patterns
        let patternScore = compareMessagePatterns(
            current.broadcastPattern,
            candidate.broadcastPattern
        )
        
        // Compare intervals
        let intervalScore = compareMessageIntervals(current, candidate)
        
        return (typeScore + signalScore + patternScore + intervalScore) / 4.0
    }
    
    private func compareMessagePatterns(_ pattern1: DroneSignature.BroadcastPattern,
                                        _ pattern2: DroneSignature.BroadcastPattern) -> Double {
        let sequence1 = pattern1.messageSequence
        let sequence2 = pattern2.messageSequence
        
        guard !sequence1.isEmpty && !sequence2.isEmpty else { return 0 }
        
        // Compare message type sequences
        let common = Set(sequence1).intersection(Set(sequence2))
        let sequenceScore = Double(common.count) / Double(max(sequence1.count, sequence2.count))
        
        // Compare consistency scores
        let consistencyDelta = abs(pattern1.consistency - pattern2.consistency)
        let consistencyScore = max(0, 1 - consistencyDelta)
        
        return (sequenceScore + consistencyScore) / 2.0
    }
    
    private func compareMessageIntervals(_ sig1: DroneSignature, _ sig2: DroneSignature) -> Double {
        guard let interval1 = sig1.messageInterval,
              let interval2 = sig2.messageInterval else {
            return 0
        }
        
        let delta = abs(interval1 - interval2)
        return max(0, 1 - (delta / Thresholds.messageIntervalDelta))
    }
    
    private func pruneCache() {
        let now = Date().timeIntervalSince1970
        if now - lastPruneTime > cachePruneInterval {
            signatureCache = signatureCache.filter { $0.value.lastUpdate > now - cachePruneInterval }
            lastPruneTime = now
        }
    }
    
    private func extractPrimaryId(_ message: [String: Any]) -> DroneSignature.IdInfo {
        if let basicId = message["Basic ID"] as? [String: Any] {
            let idTypeStr = basicId["id_type"] as? String ?? "unknown"
            let idType: DroneSignature.IdInfo.IdType = {
                switch idTypeStr {
                case "Serial Number (ANSI/CTA-2063-A)": return .serialNumber
                case "CAA Registration ID": return .caaRegistration
                case "UTM (USS) Assigned ID": return .utmAssigned
                default: return .unknown
                }
            }()
            
            return DroneSignature.IdInfo(
                id: basicId["id"] as? String ?? UUID().uuidString,
                type: idType,
                protocolVersion: message["protocol_version"] as? String ?? "1.0",
                uaType: .helicopter
            )
        }
        
        if let mac = message["MAC"] as? String {
            return DroneSignature.IdInfo(
                id: "WIFI-\(mac)",
                type: .unknown,
                protocolVersion: "1.0",
                uaType: .none
            )
        }
        
        return DroneSignature.IdInfo(
            id: UUID().uuidString,
            type: .unknown,
            protocolVersion: "1.0",
            uaType: .none
        )
    }
    
    private func extractSecondaryId(_ message: [String: Any]) -> DroneSignature.IdInfo? {
        if let auth = message["Authentication"] as? [String: Any],
           let id = auth["id"] as? String {
            return DroneSignature.IdInfo(
                id: id,
                type: .sessionId,
                protocolVersion: "1.0",
                uaType: .none
            )
        }
        return nil
    }
    
    private func extractPositionInfo(_ message: [String: Any]) -> DroneSignature.PositionInfo {
        var lat = 0.0
        var lon = 0.0
        var alt = 0.0
        
        if let location = message["Location/Vector Message"] as? [String: Any] {
            lat = location["latitude"] as? Double ?? 0.0
            lon = location["longitude"] as? Double ?? 0.0
            alt = location["geodetic_altitude"] as? Double ?? 0.0
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let operatorLocation: CLLocationCoordinate2D?
        
        if let system = message["System Message"] as? [String: Any],
           let opLat = system["latitude"] as? Double,
           let opLon = system["longitude"] as? Double {
            operatorLocation = CLLocationCoordinate2D(latitude: opLat, longitude: opLon)
        } else {
            operatorLocation = nil
        }
        
        return DroneSignature.PositionInfo(
            coordinate: coordinate,
            altitude: alt,
            altitudeReference: .wgs84,
            lastKnownGoodPosition: lat == 0 && lon == 0 ? nil : coordinate,
            operatorLocation: operatorLocation,
            horizontalAccuracy: nil,
            verticalAccuracy: nil,
            timestamp: Date().timeIntervalSince1970
        )
    }
    
    private func extractMovementVector(_ message: [String: Any], previousPath: [CLLocationCoordinate2D]?) -> DroneSignature.MovementVector {
        if let location = message["Location/Vector Message"] as? [String: Any] {
            return DroneSignature.MovementVector(
                groundSpeed: location["speed"] as? Double ?? 0.0,
                verticalSpeed: location["vert_speed"] as? Double ?? 0.0,
                heading: location["heading"] as? Double ?? 0.0,
                climbRate: nil,
                turnRate: nil,
                flightPath: previousPath,
                timestamp: Date().timeIntervalSince1970
            )
        }
        return DroneSignature.MovementVector(
            groundSpeed: 0.0,
            verticalSpeed: 0.0,
            heading: 0.0,
            climbRate: nil,
            turnRate: nil,
            flightPath: previousPath,
            timestamp: Date().timeIntervalSince1970
        )
    }
    
    private func extractHeightInfo(_ message: [String: Any], previousHeights: [Double]?) -> DroneSignature.HeightInfo {
        let location = message["Location/Vector Message"] as? [String: Any] ?? [:]
        let now = Date().timeIntervalSince1970
        let height = location["height_agl"] as? Double ?? 0.0
        
        let consistencyScore = calculateHeightConsistency(height, previousHeights: previousHeights)
        
        return DroneSignature.HeightInfo(
            heightAboveGround: height,
            heightAboveTakeoff: nil,
            referenceType: .ground,
            horizontalAccuracy: nil,
            verticalAccuracy: nil,
            consistencyScore: consistencyScore,
            lastKnownGoodHeight: height == 0 ? previousHeights?.last : height,
            timestamp: now
        )
    }
    
    private func extractTransmissionInfo(_ message: [String: Any]) -> DroneSignature.TransmissionInfo {
        var messageTypes: Set<DroneSignature.TransmissionInfo.MessageType> = []
        
        if message["Basic ID"] != nil { messageTypes.insert(.basicId) }
        if message["Location/Vector Message"] != nil { messageTypes.insert(.location) }
        if message["Authentication"] != nil { messageTypes.insert(.authentication) }
        if message["Self-ID Message"] != nil { messageTypes.insert(.selfId) }
        if message["System Message"] != nil { messageTypes.insert(.system) }
        if message["Operator ID"] != nil { messageTypes.insert(.operatorId) }
        
        let type: DroneSignature.TransmissionInfo.TransmissionType = {
            if message["AUX_ADV_IND"] != nil { return .ble }
            if message["DroneID"] != nil { return .wifi }
            if message["Basic ID"] != nil { return .esp32 }
            return .unknown
        }()
        
        return DroneSignature.TransmissionInfo(
            transmissionType: type,
            signalStrength: message["rssi"] as? Double,
            frequency: nil,
            protocolType: .openDroneID,
            messageTypes: messageTypes,
            timestamp: Date().timeIntervalSince1970
        )
    }
    
    private func extractBroadcastPattern(_ message: [String: Any], droneId: String, timestamp: TimeInterval) -> DroneSignature.BroadcastPattern {
        var sequence = [DroneSignature.TransmissionInfo.MessageType]()
        var intervals = [TimeInterval]()
        
        if let info = signatureCache[droneId] {
            sequence = info.signatures.compactMap { sig in
                sig.transmissionInfo.messageTypes.first
            }
            
            intervals = zip(info.signatures, info.signatures.dropFirst()).map {
                $1.timestamp - $0.timestamp
            }
        }
        
        return DroneSignature.BroadcastPattern(
            messageSequence: sequence,
            intervalPattern: intervals,
            consistency: calculatePatternConsistency(intervals),
            startTime: signatureCache[droneId]?.signatures.first?.timestamp ?? timestamp,
            lastUpdate: timestamp
        )
    }
    
    private func calculateHeightConsistency(_ currentHeight: Double, previousHeights: [Double]?) -> Double {
        guard let heights = previousHeights, !heights.isEmpty else {
            return 1.0  // No history to compare against
        }
        
        // Get last few readings for trend analysis
        let recentHeights = Array(heights.suffix(5))
        let heightDeltas = zip(recentHeights, recentHeights.dropFirst()).map { abs($1 - $0) }
        
        // Calculate average delta and consistency score
        let averageDelta = heightDeltas.reduce(0.0, +) / Double(heightDeltas.count)
        let consistencyThreshold = 2.0 // meters
        
        return max(0.0, min(1.0, 1.0 - (averageDelta / consistencyThreshold)))
    }
    
    private func calculatePatternConsistency(_ intervals: [TimeInterval]) -> Double {
        guard intervals.count >= 2 else {
            return 1.0  // Not enough data for pattern analysis
        }
        
        // Calculate average interval and variance
        let averageInterval = intervals.reduce(0.0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - averageInterval, 2) }.reduce(0.0, +) / Double(intervals.count)
        let standardDeviation = sqrt(variance)
        
        // Calculate consistency score based on coefficient of variation
        let coefficientOfVariation = standardDeviation / averageInterval
        let maxAcceptableVariation = 0.5 // 50% variation threshold
        
        return max(0.0, min(1.0, 1.0 - (coefficientOfVariation / maxAcceptableVariation)))
    }
    
    private func calculateMessageInterval(forId id: String) -> TimeInterval? {
        guard let info = signatureCache[id],
              info.signatures.count > 1 else {
            return nil
        }
        
        let intervals = zip(info.signatures, info.signatures.dropFirst()).map {
            $1.timestamp - $0.timestamp
        }
        
        return intervals.reduce(0, +) / Double(intervals.count)
    }
    
    private func updateSignatureCache(_ signature: DroneSignature) {
        let id = signature.primaryId.id
        var info = signatureCache[id] ?? DroneTrackingInfo(
            signatures: [],
            lastUpdate: signature.timestamp,
            confidenceScore: 1.0,
            matchHistory: [],
            flightPath: [],
            heightProfile: []
        )
        
        info.signatures.append(signature)
        info.lastUpdate = signature.timestamp
        
        if signature.position.coordinate.latitude != 0 &&
            signature.position.coordinate.longitude != 0 {
            info.flightPath.append(signature.position.coordinate)
        }
        
        info.heightProfile.append(signature.heightInfo.heightAboveGround)
        
        if info.signatures.count > 100 {
            info.signatures.removeFirst()
            info.flightPath.removeFirst()
            info.heightProfile.removeFirst()
        }
        
        signatureCache[id] = info
    }
}

