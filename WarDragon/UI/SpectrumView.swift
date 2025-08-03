//
//  SpectrumView.swift
//  WarDragon
//
//  Created by Luke on 12/26/24.
//

import SwiftUI

struct SpectrumView: View {
    @ObservedObject var viewModel: SpectrumData.SpectrumViewModel
    @State private var spectrumPort: String = String(UserDefaults.standard.integer(forKey: "spectrumPort"))
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    if viewModel.isListening {
                        viewModel.stopListening()
                    } else {
                        guard let port = Int(spectrumPort), port > 0 && port < 65536 else { return }
                        viewModel.startListening(port: UInt16(port))
                    }
                } label: {
                    Image(systemName: viewModel.isListening ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(viewModel.isListening ? .red : .green)
                }
                .padding(.horizontal)
                
                if let latest = viewModel.spectrumData.last {
                    VStack(alignment: .leading) {
                        Text(String(localized: "spectrum_center_frequency", comment: "Label showing center frequency") + ": \(formatFrequency(Double(latest.fc))))
                        Text(String(localized: "spectrum_sample_rate", comment: "Label showing sample rate") + ": \(formatFrequency(Double(latest.sampleRate))))
                        Text(String(localized: "spectrum_fft_size", comment: "Label showing FFT size") + ": \(latest.data.count))
                    }
                    .font(.system(.caption, design: .monospaced))
                }
                
                Spacer()
                
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gear")
                }
            }
            .padding(.horizontal)
            
            if let error = viewModel.connectionError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.appCaption)
            }
            
            if let latest = viewModel.spectrumData.last {
                SpectrumGraphView(data: latest)
                    .frame(height: 300)
                    .background(Color.black)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                    )
                
                WaterfallView(data: viewModel.spectrumData)
                    .frame(height: 200)
                    .background(Color.black)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                    )
            } else {
                Text(String(localized: "no_spectrum_data", comment: "Message when no spectrum data is available"))
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding()
        .navigationTitle(String(localized: "spectrum", comment: "Navigation title for spectrum view"))
        .sheet(isPresented: $showSettings) {
            NavigationView {
                Form {
                    Section(String(localized: "udp_connection", comment: "Section header for UDP connection settings")) {
                        HStack {
                            Text(String(localized: "port", comment: "Label for port setting"))
                            Spacer()
                            TextField(String(localized: "port", comment: "Placeholder for port input field"), text: $spectrumPort)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: spectrumPort) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        spectrumPort = filtered
                                    }
                                    
                                    if let port = Int(filtered),
                                       port > 0 && port < 65536 {
                                        UserDefaults.standard.set(port, forKey: "spectrumPort")
                                        if viewModel.isListening {
                                            viewModel.stopListening()
                                            viewModel.startListening(port: UInt16(port))
                                        }
                                    }
                                }
                        }
                    }
                }
                .navigationTitle(String(localized: "spectrum_settings", comment: "Title for spectrum settings sheet"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(String(localized: "done", comment: "Button to close settings")) {
                            showSettings = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func formatFrequency(_ hz: Double) -> String {
        switch hz {
        case _ where hz >= 1e9:
            return String(format: "%.3f GHz", hz/1e9)
        case _ where hz >= 1e6:
            return String(format: "%.3f MHz", hz/1e6)
        case _ where hz >= 1e3:
            return String(format: "%.3f kHz", hz/1e3)
        default:
            return String(format: "%.0f Hz", hz)
        }
    }
}

struct SpectrumGraphView: View {
    let data: SpectrumData
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let step = geometry.size.width / CGFloat(data.data.count)
                let values = data.data
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let difference = maxValue - minValue
                let scale = difference != 0 ? geometry.size.height / CGFloat(difference) : 0
                
                path.move(to: CGPoint(
                    x: 0,
                    y: geometry.size.height - CGFloat(values[0] - minValue) * scale
                ))
                
                for i in 1..<data.data.count {
                    let point = CGPoint(
                        x: CGFloat(i) * step,
                        y: geometry.size.height - CGFloat(values[i] - minValue) * scale
                    )
                    path.addLine(to: point)
                }
            }
            .stroke(Color.green, lineWidth: 1)
            
            let freqSteps = 5
            ForEach(0..<freqSteps, id: \.self) { i in
                let x = geometry.size.width * CGFloat(i) / CGFloat(freqSteps - 1)
                let freqOffset = Double(data.sampleRate) * (Double(i)/Double(freqSteps-1) - 0.5)
                let freq = Double(data.fc) + freqOffset
                
                Text(formatFrequency(freq))
                    .font(.appCaption)
                    .foregroundColor(.gray)
                    .position(x: x, y: geometry.size.height - 10)
            }
        }
    }
    
    private func formatFrequency(_ hz: Double) -> String {
        switch hz {
        case _ where hz >= 1e9:
            return String(format: "%.3f GHz", hz/1e9)
        case _ where hz >= 1e6:
            return String(format: "%.3f MHz", hz/1e6)
        case _ where hz >= 1e3:
            return String(format: "%.3f kHz", hz/1e3)
        default:
            return String(format: "%.0f Hz", hz)
        }
    }
}

struct WaterfallView: View {
    let data: [SpectrumData]
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !data.isEmpty else { return }
                
                let rowHeight = size.height / CGFloat(data.count)
                let colWidth = size.width / CGFloat(data[0].data.count)
                
                for (rowIndex, spectrum) in data.enumerated() {
                    let y = size.height - CGFloat(rowIndex + 1) * rowHeight
                    
                    let minPower = spectrum.data.min() ?? 0
                    let maxPower = spectrum.data.max() ?? 1
                    let range = maxPower - minPower
                    
                    for (binIndex, power) in spectrum.data.enumerated() {
                        let x = CGFloat(binIndex) * colWidth
                        let normalizedPower = range != 0 ? Float((power - minPower) / range) : 0
                        let color = powerToColor(Double(normalizedPower))
                        
                        let rect = CGRect(x: x, y: y, width: colWidth + 1, height: rowHeight + 1)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
    
    private func powerToColor(_ power: Double) -> Color {
        Color(
            hue: 0.75 - (power * 0.75),
            saturation: 1,
            brightness: power
        )
    }
}
