//
//  DialSliderView.swift
//  SphereSquash
//
//  Created by Benjamin Lucas on 2/27/25.
//

import SwiftUI

struct DialSliderView: View {
    
    enum Orientation {
        case horizontal, vertical
    }
    
    @Binding var value: Double

    let sliderRange: ClosedRange<Double>
    
    let frameSize: CGSize = CGSize(width: 600, height: 25)
    
    let orientation: Orientation
    
    /// Appearance properties.
    var dialSize: CGFloat = 50
    var lineWidth: CGFloat = 2
    
    let indicatorColor: Color = .white
    let tickColor: Color = .gray
    
    // Internal state to keep track of the drag start value.
    @State private var dragStartValue: Double = 0.0
    @State private var valueInterval: Double = 0.5
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
             // Background for the dial.
             Rectangle()
                 .fill(Color.black.opacity(0.2))
                 .frame( width: frameSize.width, height: frameSize.height)
             
             // Ticks drawn along the “wheel.”
             ForEach(0..<21) { i in
                 let tickThickness: CGFloat = 2//(i % 2 == 0 ? 2 : 1)
                 let tickHeight: CGFloat = frameSize.height
                 
                 let pos = CGFloat(i) * frameSize.width / 20.0
                 let offset = (valueInterval * frameSize.width / 20.0)
                 Path { path in
                     path.move(to: CGPoint(x: pos + offset, y: 0.0))
                     path.addLine(to: CGPoint(x: pos + offset, y: tickHeight ))
                 }
                 .stroke(tickColor, lineWidth: tickThickness)
             }
             // Shift ticks based on the apparent dial value.
             //.offset(x: frameSize.width * (CGFloat(value) - 0.5))
             
             // Center indicator line (horizontal line for vertical dial).
             Path { path in
                 path.move(to: CGPoint(x: frameSize.width / 2.0, y:0.0))
                 path.addLine(to: CGPoint(x: frameSize.width / 2.0, y: frameSize.height))
             }
             .stroke(indicatorColor, lineWidth: 4)
            Path { path in
                path.move(to: CGPoint(x: 0, y:frameSize.height))
                path.addLine(to: CGPoint(x: frameSize.width, y: frameSize.height))
            }
            .stroke(indicatorColor, lineWidth: 6)
             
             // Vertical indicator edge.
             Path { path in
                 path.move(to: CGPoint(x: 0.0, y: 0.0))
                 path.addLine(to: CGPoint(x: 0.0, y: frameSize.height))
             }
             .stroke(indicatorColor, lineWidth: 5)
         }
         .mask(
             LinearGradient(
                 gradient: Gradient(colors: [.clear, .clear, .white, .white, .white, .clear, .clear]),
                 startPoint: .leading,
                 endPoint: .trailing
             )
         )
         .rotationEffect(Angle(degrees: orientation == .horizontal ? 0.0: 90.0))
         .frame(width: frameSize.width, height: frameSize.height)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if !isDragging {
                            dragStartValue = valueInterval
                            isDragging = true
                        }

                        let deltaInterval: Double = ((orientation == .horizontal)
                        ? Double(gesture.translation.width)
                                                     : Double(gesture.translation.height))/frameSize.width
                        
                        
                        valueInterval = fmod(dragStartValue + deltaInterval, 1.0)
                        if(valueInterval < 0.0){
                            valueInterval += 1.0
                        }
                        
                        self.value = valueInterval * (sliderRange.upperBound - sliderRange.lowerBound) + sliderRange.lowerBound
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

#Preview {
    DialSliderView(value:.constant(0.0), sliderRange: -180...180, orientation: .horizontal)
        //.frame(width :25, height:600)
}
