//
//  DroneSignatureGenerator.swift
//  WarDragon
//
//  Created by Luke on 12/6/24.
//

import Foundation
import CoreLocation

public final class DroneSignatureGenerator {
    // MARK: - Types
    
    
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
    
    public struct DroneTrackingInfo {
        var signatures: [DroneSignature]
        var lastUpdate: TimeInterval
        var confidenceScore: Double
        var matchHistory: [SignatureMatch]
        var flightPath: [CLLocationCoordinate2D]
        var heightProfile: [Double]
        
        public init(signatures: [DroneSignature],
                    lastUpdate: TimeInterval,
                    confidenceScore: Double,
                    matchHistory: [SignatureMatch],
                    flightPath: [CLLocationCoordinate2D],
                    heightProfile: [Double]) {
            self.signatures = signatures
            self.lastUpdate = lastUpdate
            self.confidenceScore = confidenceScore
            self.matchHistory = matchHistory
            self.flightPath = flightPath
            self.heightProfile = heightProfile
        }
    }
    
    public struct SignatureMatch {
        public let timestamp: TimeInterval
        public let matchStrength: Double
        public let matchedFields: Set<MatchField>
        public let confidence: Double
        
        public enum MatchField: String {
            case primaryId
            case operatorLocation
            case position
            case movement
            case heightPattern
            case broadcastPattern
            case signalCharacteristics
        }
        
        public init(timestamp: TimeInterval,
                    matchStrength: Double,
                    matchedFields: Set<MatchField>,
                    confidence: Double) {
            self.timestamp = timestamp
            self.matchStrength = matchStrength
            self.matchedFields = matchedFields
            self.confidence = confidence
        }
    }
    
    public struct SpoofDetectionResult {
        let isSpoofed: Bool
        let confidence: Double
        let reasons: [String]
        let expectedRssi: Double
        let actualRssi: Double
        let distance: Double
    }
    
    private var monitorLocation: CLLocation?
    
    public func updateMonitorLocation(_ location: CLLocation) {
        monitorLocation = location
    }
    
    // MARK: - Properties
    private var signatureCache: [String: DroneTrackingInfo] = [:]
    private let cachePruneInterval: TimeInterval = 300
    private var lastPruneTime: TimeInterval = 0
    
    public var expectedSignal = 0.0
    public var trueSignal = 0.0
    
    // MARK: - Initialization
    public init() {}
    
    // MARK: - Public Methods
    public func createSignature(from message: [String: Any]) -> DroneSignature? {
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
        // Extract MAC addresses from all possible sources
        let currentMac = current.transmissionInfo.macAddress ??
        (current.transmissionInfo.metadata?["Basic ID"] as? [String: Any])?["MAC"] as? String ??
        (current.transmissionInfo.metadata?["AUX_ADV_IND"] as? [String: Any])?["addr"] as? String
        
        let candidateMac = candidate.transmissionInfo.macAddress ??
        (candidate.transmissionInfo.metadata?["Basic ID"] as? [String: Any])?["MAC"] as? String ??
        (candidate.transmissionInfo.metadata?["AUX_ADV_IND"] as? [String: Any])?["addr"] as? String
        
        // If we have valid MACs and they match, it's the same drone
        if let currentMac = currentMac,
           let candidateMac = candidateMac,
           !currentMac.isEmpty && !candidateMac.isEmpty &&
            currentMac == candidateMac {
            return 1.0 // Perfect match
        }
        
        var matchStrength = 0.0
        var matchedFields = Set<SignatureMatch.MatchField>()
        
        if let positionScore = matchPositionAndMovement(current, candidate) {
            matchStrength += positionScore * 0.4
            matchedFields.insert(.position)
            matchedFields.insert(.movement)
        }
        
        if let heightScore = matchHeightProfile(current, candidate) {
            matchStrength += heightScore * 0.3
            matchedFields.insert(.heightPattern)
        }
        
        if let broadcastScore = matchBroadcastCharacteristics(current, candidate) {
            matchStrength += broadcastScore * 0.3
            matchedFields.insert(.broadcastPattern)
            matchedFields.insert(.signalCharacteristics)
        }
        
        if let operatorScore = matchOperatorLocations(current, candidate) {
            matchStrength = (matchStrength * 0.8) + (operatorScore * 0.2)
            matchedFields.insert(.operatorLocation)
        }
        
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
    
    func detectSpoof(_ signature: DroneSignature, fromMonitor monitorStatus: StatusViewModel.StatusMessage) -> SpoofDetectionResult? {
        
        let rssi = signature.transmissionInfo.signalStrength
        var expectedRssi = signature.transmissionInfo.expectedSignalStrength
        
        var reasons: [String] = []
        var confidenceScore = 0.0
        
        // Calculate actual distance between monitor and drone
        let monitorPoint = CLLocation(latitude: monitorStatus.gpsData.latitude,
                                      longitude: monitorStatus.gpsData.longitude)
        let dronePoint = CLLocation(latitude: signature.position.coordinate.latitude,
                                    longitude: signature.position.coordinate.longitude)
        let distance = monitorPoint.distance(from: dronePoint)
        
        // Calculate expected RSSI using free space path loss formula
        // FSPL = 20 * log10(d) + 20 * log10(f) + 32.44
        // where d is distance in kilometers and f is frequency in MHz
        let distanceKm = distance / 1000.0
        let frequency = signature.transmissionInfo.frequency ?? 2400.0 // Default to 2.4GHz
        
        // Compare expected vs actual RSSI
        if ((rssi) != nil) {
            expectedRssi = -(20 * log10(distanceKm) + 20 * log10(frequency) + 32.44)
            let rssiDelta = abs(rssi! - (expectedRssi ?? 0.0))
            
            // Check for significant RSSI discrepancies
            if rssiDelta > 20 {
                let reason = String(format: "Signal strength deviation: %.1f dB (Expected: %.1f dB, Actual: %.1f dB at %.1f meters)",
                                    rssiDelta, expectedRssi ?? 0.0, rssi!, distance)
                reasons.append(reason)
                confidenceScore += min(rssiDelta / 40.0, 0.5)
            }
            
            // Check for unrealistic signal strength
            if rssi! > -20 && distance > 100 {
                reasons.append("Suspiciously strong signal for distance")
                confidenceScore += 0.3
            }
        }
        
        // Check cached history for this drone
        if let history = signatureCache[signature.primaryId.id] {
            // Verify speed consistency
            let speeds = calculateSpeedsBetweenPoints(history.signatures)
            if let maxSpeed = speeds.max(), maxSpeed > 139 { // > 500 km/h
                reasons.append(String(format: "Impossible speed detected: %.1f m/s", maxSpeed))
                confidenceScore += 0.3
            }
            
            //            // Check for position jumps without speed changes
            //            if let lastSig = history.signatures.last,
            //               distanceKm > 10 &&
            //                abs(lastSig.movement.groundSpeed - signature.movement.groundSpeed) < 5 {
            //                reasons.append("Large position change without corresponding speed change: \(distanceKm)")
            //                confidenceScore += 0.2
            //            }
        }
        //        print("DEGUG - Spoof confidence: \(confidenceScore)")
        
        return SpoofDetectionResult(
            isSpoofed: confidenceScore >= 0.2,
            confidence: confidenceScore,
            reasons: reasons,
            expectedRssi: expectedRssi ?? 0.0,
            actualRssi: rssi ?? 0.0,
            distance: distance
        )
        
    }
    
    // MARK: - Private Methods
    
    private func calculateSpeedsBetweenPoints(_ signatures: [DroneSignature]) -> [Double] {
        var speeds: [Double] = []
        
        for i in 1..<signatures.count {
            let prev = signatures[i-1]
            let curr = signatures[i]
            
            let prevLocation = CLLocation(latitude: prev.position.coordinate.latitude,
                                          longitude: prev.position.coordinate.longitude)
            let currLocation = CLLocation(latitude: curr.position.coordinate.latitude,
                                          longitude: curr.position.coordinate.longitude)
            
            let distance = prevLocation.distance(from: currLocation)
            let timeInterval = curr.timestamp - prev.timestamp
            
            if timeInterval > 0 {
                let speed = distance / timeInterval // m/s
                speeds.append(speed)
            }
        }
        
        return speeds
    }
    
    private func calculateMatchConfidence(_ matchedFields: Set<SignatureMatch.MatchField>) -> Double {
        let weights: [SignatureMatch.MatchField: Double] = [
            .primaryId: 0.3,
            .operatorLocation: 0.15,
            .position: 0.15,
            .movement: 0.15,
            .heightPattern: 0.1,
            .broadcastPattern: 0.1,
            .signalCharacteristics: 0.05
        ]
        
        return matchedFields.reduce(0.0) { sum, field in
            sum + (weights[field] ?? 0.0)
        }
    }
    
    private func updateMatchHistory(_ id: String, _ match: SignatureMatch) {
        var info = signatureCache[id]
        
        // Append the match to the history
        info?.matchHistory.append(match)
        
        // Ensure we only try to remove the first element if the collection is not empty
        if let history = info?.matchHistory, history.count > 100 {
            info?.matchHistory.removeFirst()
        }
        
        // Update the signature cache with the modified info
        signatureCache[id] = info
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
        
        let positionScore = max(0, 1 - (distance / Thresholds.horizontalPositionMeters))
        let speedScore = max(0, 1 - (speedDelta / Thresholds.speedDeltaMS))
        let vspeedScore = max(0, 1 - (vspeedDelta / Thresholds.speedDeltaMS))
        
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
        
        var profileScore = 0.0
        if currentHistory.count >= 3 && candidateHistory.count >= 3 {
            profileScore = compareHeightProfiles(currentHistory, candidateHistory)
        }
        
        return (heightScore + consistencyScore + profileScore) / 3.0
    }
    
    private func compareHeightProfiles(_ profile1: [Double], _ profile2: [Double]) -> Double {
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
        
        var signalScore = 1.0
        if let signal1 = current.transmissionInfo.signalStrength,
           let signal2 = candidate.transmissionInfo.signalStrength {
            let delta = abs(signal1 - signal2)
            signalScore = max(0, 1 - (delta / Thresholds.signalStrengthDelta))
        }
        
        let patternScore = compareMessagePatterns(
            current.broadcastPattern,
            candidate.broadcastPattern
        )
        
        let intervalScore = compareMessageIntervals(current, candidate)
        
        return (typeScore + signalScore + patternScore + intervalScore) / 4.0
    }
    
    private func compareMessagePatterns(_ pattern1: DroneSignature.BroadcastPattern,
                                        _ pattern2: DroneSignature.BroadcastPattern) -> Double {
        let sequence1 = pattern1.messageSequence
        let sequence2 = pattern2.messageSequence
        
        guard !sequence1.isEmpty && !sequence2.isEmpty else { return 0 }
        
        let common = Set(sequence1).intersection(Set(sequence2))
        let sequenceScore = Double(common.count) / Double(max(sequence1.count, sequence2.count))
        
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
    
    private func generateFingerprint(from data: [String: Any]) -> String {
        var hasher = Hasher()
        hasher.combine(data.description)
        return String(format: "%08x", abs(hasher.finalize()))
    }
    
    private func extractPrimaryId(_ message: [String: Any]) -> DroneSignature.IdInfo {
        if let basicId = message["Basic ID"] as? [String: Any] {
            // Get UA type from message
            // Handle both numeric and string UA types
            let uaType: DroneSignature.IdInfo.UAType
            if let uaTypeNum = basicId["ua_type"] as? Int {
                uaType = mapUAType(uaTypeNum)
            } else if let uaTypeStr = basicId["ua_type"] as? String,
                      let uaTypeNum = Int(uaTypeStr) {
                uaType = mapUAType(uaTypeNum)
            } else {
                uaType = .helicopter  // Default if we can't parse UA type
            }
            
            return DroneSignature.IdInfo(
                id: basicId["id"] as? String ?? "Unknown",
                type: .utmAssigned,
                protocolVersion: "1.0",
                uaType: uaType
            )
        } else if message["AUX_ADV_IND"] != nil {
            let addr = (message["AUX_ADV_IND"] as? [String: Any])?["addr"] as? String ?? "Unknown"
            return DroneSignature.IdInfo(
                id: "ID: \(addr)",
                type: .serialNumber,
                protocolVersion: "1.0",
                uaType: .none // Default until we parse BT UA type
            )
        } else if let droneId = message["DroneID"] as? [String: Any] {
            let mac = droneId.keys.first ?? "Unknown"
            return DroneSignature.IdInfo(
                id: "ID: \(mac)",
                type: .unknown,
                protocolVersion: "1.0",
                uaType: .none // Default until we parse WiFi UA type
            )
        }
        
        return DroneSignature.IdInfo(
            id: "Unknown",
            type: .unknown,
            protocolVersion: "1.0",
            uaType: .helicopter
        )
    }
    
    private func mapUAType(_ value: Int) -> DroneSignature.IdInfo.UAType {
        switch value {
        case 0: return .none
        case 1: return .aeroplane
        case 2: return .helicopter
        case 3: return .gyroplane
        case 4: return .hybridLift
        case 5: return .ornithopter
        case 6: return .glider
        case 7: return .kite
        case 8: return .freeballoon
        case 9: return .captive
        case 10: return .airship
        case 11: return .freeFall
        case 12: return .rocket
        case 13: return .tethered
        case 14: return .groundObstacle
        default: return .other
        }
    }
    
    private func extractSecondaryId(_ message: [String: Any]) -> DroneSignature.IdInfo? {
        return nil // Not needed for our message types
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
    
    public func extractTransmissionInfo(_ message: [String: Any]) -> DroneSignature.TransmissionInfo {
        let type: DroneSignature.TransmissionInfo.TransmissionType
        let messageType: DroneSignature.TransmissionInfo.MessageType
        var metadata: [String: Any]? = nil
        var channel: Int? = nil
        var advMode: String? = nil
        var advAddress: String? = nil
        var did: Int? = nil
        var sid: Int? = nil
        var signalStrength: Double?
        var expectedSignalStrength: Double?
        
        if let remarks = (message["detail"] as? [String: Any])?["remarks"] as? String {
            // Extract RSSI value using a cleaner regex
            if let rssiRange = remarks.range(of: "-\\d+(?=dBm)", options: .regularExpression) {
                let rssiString = String(remarks[rssiRange])
                signalStrength = Double(rssiString)
            }
        }
        
        // Calculate expected signal strength for both formats
        if let location = message["Location/Vector Message"] as? [String: Any],
           let lat = location["latitude"] as? Double,
           let lon = location["longitude"] as? Double,
           let monitorLoc = monitorLocation {
            let droneLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = droneLocation.distance(from: monitorLoc)
            expectedSignalStrength = calculateExpectedRSSI(distance: distance)
        } else if let point = message["point"] as? [String: Any],
                  let lat = Double(point["lat"] as? String ?? "0.0"),
                  let lon = Double(point["lon"] as? String ?? "0.0"),
                  let monitorLoc = monitorLocation {
            let droneLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = droneLocation.distance(from: monitorLoc)
            expectedSignalStrength = calculateExpectedRSSI(distance: distance)
        }
        
        // Check multiple sources for RSSI
        if let auxAdvInd = message["AUX_ADV_IND"] as? [String: Any],
           let rssi = auxAdvInd["rssi"] as? Double {
            signalStrength = rssi
        } else if let basicId = message["Basic ID"] as? [String: Any],
                  let rssi = basicId["RSSI"] as? Double {
            signalStrength = rssi
        } else if let basicId = message["Basic ID"] as? [String: Any],
                  let rssi = basicId["rssi"] as? Double {
            signalStrength = rssi
        } else if let locationVector = message["Location/Vector Message"] as? [String: Any],
                  let rssi = locationVector["rssi"] as? Double {
            signalStrength = rssi
        }
        
        if let auxAdvInd = message["AUX_ADV_IND"] as? [String: Any] {
            type = .ble  // use BT for WiFI too
            messageType = .bt45
            metadata = auxAdvInd
            channel = auxAdvInd["chan"] as? Int
            
            if let aext = message["aext"] as? [String: Any] {
                advMode = aext["AdvMode"] as? String
                advAddress = (aext["AdvA"] as? String)?.components(separatedBy: " ").first
                did = (aext["AdvDataInfo"] as? [String: Any])?["did"] as? Int
                sid = (aext["AdvDataInfo"] as? [String: Any])?["sid"] as? Int
            }
        } else if message["DroneID"] != nil {
            type = .wifi
            messageType = .wifi
        } else if message["Basic ID"] != nil {
            type = .esp32 // or BT
            messageType = .esp32
        } else {
            type = .unknown
            messageType = .bt45
        }
        
        // Calculate expected signal strength if possible
        if let location = message["Location/Vector Message"] as? [String: Any],
           let lat = location["latitude"] as? Double,
           let lon = location["longitude"] as? Double,
           let monitorLoc = monitorLocation {
            let droneLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = droneLocation.distance(from: monitorLoc)
            expectedSignalStrength = calculateExpectedRSSI(distance: distance)
        } else if let point = message["point"] as? [String: Any],
                  let lat = point["lat"] as? String,
                  let lon = point["lon"] as? String,
                  let latDouble = Double(lat),
                  let lonDouble = Double(lon) {
            // Handle XML point format
            let distanceFromOrigin = sqrt(latDouble * latDouble + lonDouble * lonDouble) * 111000
            expectedSignalStrength = calculateExpectedRSSI(distance: distanceFromOrigin)
        }
        
        return DroneSignature.TransmissionInfo(
            transmissionType: type,
            signalStrength: signalStrength,
            expectedSignalStrength: expectedSignalStrength,
            macAddress: ((message["Basic ID"] as? [String: Any])?["MAC"]) as? String,
            frequency: nil,
            protocolType: .openDroneID,
            messageTypes: [messageType],
            timestamp: Date().timeIntervalSince1970,
            metadata: metadata,
            channel: channel,
            advMode: advMode,
            advAddress: advAddress,
            did: did,
            sid: sid
        )
        
    }
    
    private func calculateExpectedRSSI(distance: Double) -> Double? {
        guard distance > 0 else { return nil }
        
        let distanceKm = distance / 1000.0
        let frequency = 2400.0 // 2.4GHz for BLE
        
        // Free Space Path Loss (FSPL) formula
        return -(20 * log10(distanceKm) + 20 * log10(frequency) + 32.44)
    }
    
    private func extractBroadcastPattern(_ message: [String: Any], droneId: String, timestamp: TimeInterval) -> DroneSignature.BroadcastPattern {
        var messageType: DroneSignature.TransmissionInfo.MessageType = .bt45
        if message["AUX_ADV_IND"] != nil {
            messageType = .bt45
        } else if message["DroneID"] != nil {
            messageType = .wifi
        } else if message["Basic ID"] != nil {
            messageType = .esp32
        }
        
        var intervals = [TimeInterval]()
        if let info = signatureCache[droneId] {
            intervals = zip(info.signatures, info.signatures.dropFirst()).map {
                $1.timestamp - $0.timestamp
            }
        }
        
        return DroneSignature.BroadcastPattern(
            messageSequence: [messageType],
            intervalPattern: intervals,
            consistency: calculatePatternConsistency(intervals),
            startTime: signatureCache[droneId]?.signatures.first?.timestamp ?? timestamp,
            lastUpdate: timestamp
        )
    }
    
    private func calculateHeightConsistency(_ currentHeight: Double, previousHeights: [Double]?) -> Double {
        guard let heights = previousHeights, !heights.isEmpty else {
            return 1.0
        }
        
        let recentHeights = Array(heights.suffix(5))
        let heightDeltas = zip(recentHeights, recentHeights.dropFirst()).map { abs($1 - $0) }
        
        let averageDelta = heightDeltas.reduce(0.0, +) / Double(heightDeltas.count)
        let consistencyThreshold = 2.0
        
        return max(0.0, min(1.0, 1.0 - (averageDelta / consistencyThreshold)))
    }
    
    private func calculatePatternConsistency(_ intervals: [TimeInterval]) -> Double {
        guard intervals.count >= 2 else {
            return 1.0
        }
        
        let averageInterval = intervals.reduce(0.0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - averageInterval, 2) }.reduce(0.0, +) / Double(intervals.count)
        let standardDeviation = sqrt(variance)
        
        let coefficientOfVariation = standardDeviation / averageInterval
        let maxAcceptableVariation = 0.5
        
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
        
        if signature.position.coordinate.latitude != 0 && signature.position.coordinate.longitude != 0 {
            info.flightPath.append(signature.position.coordinate)
        }
        
        info.heightProfile.append(signature.heightInfo.heightAboveGround)
        
        // Safely remove first elements if collections have more than 100 items
        if info.signatures.count > 100 {
            if !info.signatures.isEmpty { info.signatures.removeFirst() }
            if !info.flightPath.isEmpty { info.flightPath.removeFirst() }
            if !info.heightProfile.isEmpty { info.heightProfile.removeFirst() }
        }
        
        signatureCache[id] = info
    }
    
}
