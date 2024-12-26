//
//  SpectrumData.swift
//  WarDragon
//
//  Created by Luke on 12/26/24.
//

import Foundation

struct SpectrumData: Identifiable, Codable {
    var id = UUID()
    let timestamp: TimeInterval
    let centerFreq: Double
    let bandwidth: Double
    let sampleRate: Double
    let gain: Double
    let spectrum: [Double]
    let frequencyPoints: [Double]
}

class SpectrumViewModel: ObservableObject {
    @Published var spectrumData: [SpectrumData] = []
    @Published var isRecording = false
    @Published var selectedFrequency: Double = 915.0
    @Published var selectedBandwidth: Double = 20.0
    
    func updateSpectrum(_ data: SpectrumData) {
        DispatchQueue.main.async {
            self.spectrumData.append(data)
            if self.spectrumData.count > 100 {
                self.spectrumData.removeFirst()
            }
        }
    }
}
