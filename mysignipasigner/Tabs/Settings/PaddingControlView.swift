//
//  PaddingControlView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Combine

struct PaddingControlView: View {
    let title: String
    let currentValue: Double
    let range: ClosedRange<Double>
    let onValueChange: (Double) -> Void
    let accentColor: Color
    let defaultValue: Double
    
    @State private var sliderValue: Double
    @State private var textValue: String
    
    init(title: String, currentValue: Double, range: ClosedRange<Double>, onValueChange: @escaping (Double) -> Void, accentColor: Color, defaultValue: Double) {
        self.title = title
        self.currentValue = currentValue
        self.range = range
        self.onValueChange = onValueChange
        self.accentColor = accentColor
        self.defaultValue = defaultValue
        self._sliderValue = State(initialValue: currentValue)
        self._textValue = State(initialValue: "\(Int(currentValue))")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and current value
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 4) {
                    Text("\(Int(sliderValue))")
                        .foregroundColor(accentColor)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("(\(Int(defaultValue)))")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .frame(minWidth: 60, alignment: .trailing)
            }
            
            Slider(value: $sliderValue, in: range, step: 1) { editing in
                if !editing {
                    onValueChange(sliderValue)
                    textValue = "\(Int(sliderValue))"
                }
                HapticManager.shared.medium()
            }
            .accentColor(accentColor)
            .onChange(of: sliderValue) { newValue in
                textValue = "\(Int(newValue))"
            }
            .onChange(of: currentValue) { newValue in
                if abs(sliderValue - newValue) > 0.1 {
                    sliderValue = newValue
                    textValue = "\(Int(newValue))"
                }
            }
            .onAppear {
                sliderValue = currentValue
                textValue = "\(Int(currentValue))"
            }
            
            TextField("Enter value", text: $textValue)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numbersAndPunctuation)
                .onSubmit {
                    if let value = Double(textValue) {
                        let clampedValue = max(range.lowerBound, min(range.upperBound, value))
                        sliderValue = clampedValue
                        textValue = "\(Int(clampedValue))"
                        onValueChange(clampedValue)
                        HapticManager.shared.medium()
                    } else {
                        // Reset to current value if invalid
                        textValue = "\(Int(sliderValue))"
                    }
                }
                .onChange(of: textValue) { newText in
                    // Real-time validation and update (optional)
                    if let value = Double(newText) {
                        let clampedValue = max(range.lowerBound, min(range.upperBound, value))
                        if abs(sliderValue - clampedValue) > 0.1 {
                            sliderValue = clampedValue
                        }
                    }
                }
        }
        .padding(.vertical, 8)
    }
}

struct ScaleControlView: View {
    let title: String
    let currentValue: Double
    let range: ClosedRange<Double>
    let onValueChange: (Double) -> Void
    let accentColor: Color
    let defaultValue: Double
    
    @State private var sliderValue: Double
    @State private var textValue: String
    
    init(title: String, currentValue: Double, range: ClosedRange<Double>, onValueChange: @escaping (Double) -> Void, accentColor: Color, defaultValue: Double) {
        self.title = title
        self.currentValue = currentValue
        self.range = range
        self.onValueChange = onValueChange
        self.accentColor = accentColor
        self.defaultValue = defaultValue
        self._sliderValue = State(initialValue: currentValue)
        self._textValue = State(initialValue: String(format: "%.1f", currentValue))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and current value
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", sliderValue))
                        .foregroundColor(accentColor)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("(\(String(format: "%.1f", defaultValue)))")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .frame(minWidth: 80, alignment: .trailing)
            }
            
            Slider(value: $sliderValue, in: range, step: 0.1) { editing in
                if !editing {
                    onValueChange(sliderValue)
                    textValue = String(format: "%.1f", sliderValue)
                }
                HapticManager.shared.medium()
            }
            .accentColor(accentColor)
            .onChange(of: sliderValue) { newValue in
                textValue = String(format: "%.1f", newValue)
            }
            .onChange(of: currentValue) { newValue in
                if abs(sliderValue - newValue) > 0.01 {
                    sliderValue = newValue
                    textValue = String(format: "%.1f", newValue)
                }
            }
            .onAppear {
                sliderValue = currentValue
                textValue = String(format: "%.1f", currentValue)
            }
            
            TextField("Enter value", text: $textValue)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
                .onSubmit {
                    if let value = Double(textValue) {
                        let clampedValue = max(range.lowerBound, min(range.upperBound, value))
                        sliderValue = clampedValue
                        textValue = String(format: "%.1f", clampedValue)
                        onValueChange(clampedValue)
                        HapticManager.shared.medium()
                    } else {
                        // Reset to current value if invalid
                        textValue = String(format: "%.1f", sliderValue)
                    }
                }
                .onChange(of: textValue) { newText in
                    // Real-time validation and update (optional)
                    if let value = Double(newText) {
                        let clampedValue = max(range.lowerBound, min(range.upperBound, value))
                        if abs(sliderValue - clampedValue) > 0.01 {
                            sliderValue = clampedValue
                        }
                    }
                }
        }
        .padding(.vertical, 8)
    }
}

struct PaddingButton: View {
    let text: String
    let action: () -> Void
    let accentColor: Color
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(accentColor)
                .frame(minWidth: 32, minHeight: 28)
                .background(accentColor.opacity(0.1))
                .cornerRadius(6)
        }
    }
}
