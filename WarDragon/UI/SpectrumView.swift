//
//  SpectrumView.swift
//  WarDragon
//
//  Created by Luke on 12/26/24.
//

import SwiftUI

struct SpectrumView: View {
    @ObservedObject var viewModel: SpectrumViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    viewModel.isRecording.toggle()
                }) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(viewModel.isRecording ? .red : .green)
                }
                .padding(.horizontal)
                
                VStack {
                    HStack {
                        Text("Frequency")
                        Slider(value: $viewModel.selectedFrequency, in: 70...6000, step: 1)
                        Text("\(Int(viewModel.selectedFrequency)) MHz")
                    }
                    
                    HStack {
                        Text("Bandwidth")
                        Slider(value: $viewModel.selectedBandwidth, in: 1...56, step: 1)
                        Text("\(Int(viewModel.selectedBandwidth)) MHz")
                    }
                }
            }
            .padding()
            
            SpectrumGraphView(data: viewModel.spectrumData.last?.spectrum ?? [])
                .frame(height: 300)
                .background(Color.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
            
            WaterfallView(spectrumData: viewModel.spectrumData)
                .frame(height: 200)
                .background(Color.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct SpectrumGraphView: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let step = geometry.size.width / CGFloat(data.count - 1)
                let scale = geometry.size.height / 120 // -120 to 0 dB range
                
                path.move(to: CGPoint(x: 0, y: geometry.size.height - CGFloat(data[0] + 120) * scale))
                
                for i in 1..<data.count {
                    let point = CGPoint(
                        x: CGFloat(i) * step,
                        y: geometry.size.height - CGFloat(data[i] + 120) * scale
                    )
                    path.addLine(to: point)
                }
            }
            .stroke(Color.green, lineWidth: 2)
            
            // Grid lines
            let dbSteps = stride(from: -120, through: 0, by: 20)
            ForEach(Array(dbSteps), id: \.self) { db in
                let y = geometry.size.height - CGFloat(db + 120) * (geometry.size.height / 120)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                
                Text("\(db) dB")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .position(x: 25, y: y)
            }
        }
    }
}

struct WaterfallView: View {
    let spectrumData: [SpectrumData]
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                context.blendMode = .plusLighter
                
                for (index, data) in spectrumData.enumerated() {
                    let y = size.height - (CGFloat(index) * size.height / CGFloat(spectrumData.count))
                    let height = size.height / CGFloat(spectrumData.count)
                    
                    for (freqIndex, power) in data.spectrum.enumerated() {
                        let x = CGFloat(freqIndex) * size.width / CGFloat(data.spectrum.count)
                        let width = size.width / CGFloat(data.spectrum.count)
                        
                        context.fill(
                            Path(CGRect(x: x, y: y, width: width, height: height)),
                            with: .color(powerToColor(power))
                        )
                    }
                }
            }
        }
    }
    
    func powerToColor(_ power: Double) -> Color {
        let normalized = (power + 120) / 120 // -120 to 0 dB range
        return Color(
            hue: 0.3, // Green hue
            saturation: 1,
            brightness: Double(normalized)
        )
    }
}
