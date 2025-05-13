//
//  TacDial.swift
//  WarDragon
//
//  Created by Luke on 1/20/25.
//

import Foundation
import SwiftUI
import UIKit

struct TacDial: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let color: Color
    
    private let lineWidth: CGFloat = 3
    private let radius: CGFloat = 60
    
    var body: some View {
        VStack {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)
                
                // Value arc
                Circle()
                    .trim(from: 0, to: CGFloat((value.wrappedValue - range.lowerBound) / (range.upperBound - range.lowerBound)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                // Current value
                VStack(spacing: 2) {
                    Text("\(Int(value.wrappedValue))")
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(color)
                    Text(unit)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(color)
                }
                
                // Control knob
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(360 * (value.wrappedValue - range.lowerBound) / (range.upperBound - range.lowerBound)))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let center = CGPoint(x: radius, y: radius)
                                let location = gesture.location
                                let dx = location.x - center.x
                                let dy = -(location.y - center.y)
                                let angle = (dx == 0 && dy == 0) ? 0 : atan2(dx, dy)
                                var degrees = angle * 180 / .pi
                                if degrees < 0 { degrees += 360 }
                                
                                let normalizedValue = degrees / 360.0
                                let newValue = range.lowerBound + normalizedValue * (range.upperBound - range.lowerBound)
                                let steppedValue = (round(newValue / step) * step)
                                if range.contains(steppedValue) {
                                    value.wrappedValue = steppedValue
                                }
                            }
                    )
            }
            .frame(width: radius * 2, height: radius * 2)
            
            Text(title)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}
