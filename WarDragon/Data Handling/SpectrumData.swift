//
//  SpectrumData.swift
//  WarDragon
//
//  Created by Luke on 12/26/24.
//

import Foundation
import Network

struct SpectrumData: Codable, Identifiable {
    static let SUSCAN_REMOTE_FRAGMENT_HEADER_MAGIC: UInt32 = 0xABCD0123
    static let SUSCAN_ANALYZER_SUPERFRAME_TYPE_PSD: UInt8 = 0x02
    
    struct RemoteHeader {
        let magic: UInt32     // 0xABCD0123
        let sfType: UInt8     // Type 0x02 for PSD
        let size: UInt16      // Fragment size
        let sfId: UInt8       // Fragment ID
        let sfSize: UInt32    // Total data size
        let sfOffset: UInt32  // Offset in data
        
        init(data: Data) {
            var offset = 0
            magic = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
            offset += MemoryLayout<UInt32>.size
            sfType = data[offset]; offset += 1
            size = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self) }
            offset += MemoryLayout<UInt16>.size
            sfId = data[offset]; offset += 1
            sfSize = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
            offset += MemoryLayout<UInt32>.size
            sfOffset = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
        }
        
        static var headerSize: Int {
            return MemoryLayout<UInt32>.size + 1 + MemoryLayout<UInt16>.size + 1 + MemoryLayout<UInt32>.size * 2
        }
    }
    
    var id: UUID
    var fc: Int              // Center frequency
    var timestamp: Double
    var sampleRate: Float    // Sample rate in Hz
    var data: [Float]        // FFT data points
    
    @MainActor
    class SpectrumViewModel: ObservableObject {
        @Published private(set) var spectrumData: [SpectrumData] = []
        @Published private(set) var isListening = false
        @Published var connectionError: String?
        
        private var connection: NWConnection?
        private let queue = DispatchQueue(label: "com.wardragon.spectrum")
        private var fragmentBuffer: [UInt8: (timestamp: Double, data: Data)] = [:]
        
        func startListening(port: UInt16) {
            guard !isListening else { return }
            
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            parameters.prohibitedInterfaceTypes = [.cellular]
            parameters.requiredInterfaceType = .wifi
            
            connection = NWConnection(
                to: NWEndpoint.hostPort(
                    host: NWEndpoint.Host("0.0.0.0"),
                    port: NWEndpoint.Port(integerLiteral: port)
                ),
                using: parameters
            )
            
            connection?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isListening = true
                        self?.connectionError = nil
                        await self?.receiveData()
                    case .failed(let error):
                        self?.isListening = false
                        self?.connectionError = error.localizedDescription
                    case .cancelled:
                        self?.isListening = false
                        self?.connectionError = nil
                    default:
                        break
                    }
                }
            }
            
            connection?.start(queue: queue)
        }
        
        private func receiveData() async {
            connection?.receiveMessage { [weak self] content, _, _, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.connectionError = error.localizedDescription
                    }
                    return
                }
                
                if let data = content {
                    Task { @MainActor in
                        await self.processFragment(data)
                    }
                }
                
                Task { @MainActor in
                    if self.isListening {
                        await self.receiveData()
                    }
                }
            }
        }
        
        private func processFragment(_ data: Data) async {
            guard data.count >= RemoteHeader.headerSize else { return }
            
            let header = RemoteHeader(data: data)
            guard header.magic == SpectrumData.SUSCAN_REMOTE_FRAGMENT_HEADER_MAGIC else { return }
            guard header.sfType == SpectrumData.SUSCAN_ANALYZER_SUPERFRAME_TYPE_PSD else { return }
            
            let payload = data.dropFirst(RemoteHeader.headerSize)
            let now = Date().timeIntervalSince1970
            
            // Store fragment
            if fragmentBuffer[header.sfId] == nil {
                fragmentBuffer[header.sfId] = (timestamp: now, data: Data())
            }
            fragmentBuffer[header.sfId]?.data.append(payload)
            
            // Check if fragment is complete
            if let fragment = fragmentBuffer[header.sfId], fragment.data.count >= header.sfSize {
                let spectralData = fragment.data.withUnsafeBytes { ptr -> [Float] in
                    Array(UnsafeBufferPointer(
                        start: ptr.baseAddress?.assumingMemoryBound(to: Float.self),
                        count: fragment.data.count / MemoryLayout<Float>.size))
                }
                
                // First float is center freq, second is sample rate, rest is FFT data
                let spectrum = SpectrumData(
                    id: UUID(),
                    fc: Int(spectralData[0]),
                    timestamp: fragment.timestamp,
                    sampleRate: spectralData[1],
                    data: Array(spectralData.dropFirst(2))
                )
                
                self.spectrumData.append(spectrum)
                if self.spectrumData.count > 100 {
                    self.spectrumData.removeFirst()
                }
                
                fragmentBuffer[header.sfId] = nil
            }
        }
        
        func stopListening() {
            connection?.cancel()
            connection = nil
            isListening = false
            connectionError = nil
            fragmentBuffer.removeAll()
        }
    }
}
