//
//  SpectrumData.swift
//  WarDragon
//
//  Created by Luke on 12/26/24.
//


import Foundation
import Network

struct SpectrumData: Codable, Identifiable {
    var id: UUID
    let type: String
    let fc: Int
    let inspector_id: Int
    let timestamp: Double
    let rt_time: Double
    let looped: Bool
    let samp_rate: Double
    let measured_samp_rate: Int
    let psd_size: Int
    let local_timestamp: Double
    var data: [Float]
    
    private enum CodingKeys: String, CodingKey {
        case type, fc, inspector_id, timestamp, rt_time, looped, samp_rate
        case measured_samp_rate, psd_size, local_timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        type = try container.decode(String.self, forKey: .type)
        fc = try container.decode(Int.self, forKey: .fc)
        inspector_id = try container.decode(Int.self, forKey: .inspector_id)
        timestamp = try container.decode(Double.self, forKey: .timestamp)
        rt_time = try container.decode(Double.self, forKey: .rt_time)
        looped = try container.decode(Bool.self, forKey: .looped)
        samp_rate = try container.decode(Double.self, forKey: .samp_rate)
        measured_samp_rate = try container.decode(Int.self, forKey: .measured_samp_rate)
        psd_size = try container.decode(Int.self, forKey: .psd_size)
        local_timestamp = try container.decode(Double.self, forKey: .local_timestamp)
        data = []
    }
    
    @MainActor
    class SpectrumViewModel: ObservableObject {
        @Published private(set) var spectrumData: [SpectrumData] = []
        @Published private(set) var isListening = false
        @Published var connectionError: String?
        
        private var connection: NWConnection?
        private let queue = DispatchQueue(label: "com.wardragon.spectrum")
        
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
            connection?.receiveMessage { [weak self] content, _, isComplete, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.connectionError = error.localizedDescription
                    }
                    return
                }
                
                if let data = content {
                    Task { @MainActor in
                        await self.processSpectrumData(data)
                    }
                }
                
                Task { @MainActor in
                    if self.isListening {
                        await self.receiveData()
                    }
                }
            }
        }
        
        private func processSpectrumData(_ data: Data) async {
            guard let splitIndex = data.firstIndex(of: UInt8(ascii: "}")) else { return }
            
            let jsonData = data[...splitIndex]
            let binaryData = data[(splitIndex + 1)...]
            
            do {
                var spectrum = try JSONDecoder().decode(SpectrumData.self, from: Data(jsonData))
                spectrum.data = binaryData.withUnsafeBytes { ptr in
                    Array(ptr.bindMemory(to: Float.self))
                }
                
                self.spectrumData.append(spectrum)
                if self.spectrumData.count > 100 {
                    self.spectrumData.removeFirst()
                }
                self.connectionError = nil
            } catch {
                self.connectionError = "Decode error: \(error.localizedDescription)"
            }
        }
        
        func stopListening() {
            connection?.cancel()
            connection = nil
            isListening = false
            connectionError = nil
        }
        
    }
}
