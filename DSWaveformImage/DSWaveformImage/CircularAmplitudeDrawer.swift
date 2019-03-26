import Foundation
import UIKit

public struct CircularAmplitudeDrawer: ImageDrawer {
    public init() {}
    
    private let density: CGFloat = 12.0
    private var shiftDegree: CGFloat = 0.0
    private var padding: CGFloat = 0.0
    
    public func waveformImage(from waveform: Waveform, with configuration: WaveformConfiguration) -> UIImage? {
        let scaledSize = CGSize(width: configuration.size.width * configuration.scale,
                                height: configuration.size.height * configuration.scale)
        let scaledConfiguration = WaveformConfiguration(size: scaledSize,
                                                        color: configuration.color,
                                                        backgroundColor: configuration.backgroundColor,
                                                        style: configuration.style,
                                                        position: configuration.position,
                                                        scale: configuration.scale,
                                                        paddingFactor: configuration.paddingFactor)
        return render(waveform: waveform, with: scaledConfiguration)
    }
}

// MARK: Image generation

private extension CircularAmplitudeDrawer {
    func render(waveform: Waveform, with configuration: WaveformConfiguration) -> UIImage? {
        let sampleCount = Int(configuration.size.width * configuration.scale)
        guard let imageSamples = waveform.samples(count: sampleCount) else { return nil }
        return graphImage(from: imageSamples, with: configuration)
    }
    
    private func arcPositions(dotRadius: CGFloat, on radius: CGFloat) -> [CGFloat] {
        let circlesFitting = (2 * dotRadius) > radius
            ? 1
            : max(1, Int((density * .pi / (asin((2 * dotRadius) / radius)))))
        let stepSize = 2 * .pi / CGFloat(circlesFitting - 1)
        return (0..<circlesFitting).map { CGFloat($0) * stepSize }
    }
    
    func position(around center: CGPoint, on radius: CGFloat, rad: CGFloat, distance: CGFloat) -> CGPoint {
        let shiftedRad = rad + (shiftDegree * distance) / 180 * .pi
        let x = center.x + (radius - padding) * distance * cos(-shiftedRad)
        let y = center.y + (radius - padding) * distance * sin(-shiftedRad)
        return CGPoint(x: x, y: y)
    }
    
    private func graphImage(from samples: [Float], with configuration: WaveformConfiguration) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(configuration.size, false, configuration.scale)
        let context = UIGraphicsGetCurrentContext()!
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        
        drawBackground(on: context, with: configuration)
        drawGraph(from: samples, on: context, with: configuration)
        
        let graphImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return graphImage
    }
    
    private func drawBackground(on context: CGContext, with configuration: WaveformConfiguration) {
        context.setFillColor(configuration.backgroundColor.cgColor)
        context.fill(CGRect(origin: CGPoint.zero, size: configuration.size))
    }
    
    private func drawGraph(from samples: [Float],
                           on context: CGContext,
                           with configuration: WaveformConfiguration) {
        let graphRect = CGRect(origin: CGPoint.zero, size: configuration.size)
        let positionAdjustedGraphCenterX = CGFloat(configuration.position.value()) * graphRect.size.width
        let positionAdjustedGraphCenterY = CGFloat(configuration.position.value()) * graphRect.size.height
        let center = CGPoint(x: positionAdjustedGraphCenterX, y: positionAdjustedGraphCenterY) // scale
        let verticalPaddingDivisor = configuration.paddingFactor ?? CGFloat(configuration.position.value() == 0.5 ? 2.5 : 1.5)
        let drawMappingFactor = graphRect.size.height / 2 / 2 / verticalPaddingDivisor
        let minimumGraphAmplitude: CGFloat = 1 // we want to see at least a 1pt line for silence
        
        let innerRadius = 30 // TODO: dynamic
        let maxOuterRadius = 100 // TODO: dynamic and also correctly based on orientation (Pythagoras)
        
        let path = CGMutablePath()
        context.setLineWidth(1.0 / configuration.scale)
        for (x, sample) in samples.enumerated() {
            let xPos = CGFloat(x) / configuration.scale
            let invertedDbSample = 1 - CGFloat(sample) // sample is in dB, linearly normalized to [0, 1] (1 -> -50 dB)
            let drawingAmplitude = max(minimumGraphAmplitude, invertedDbSample * drawMappingFactor)
            let drawingAmplitudeUp = positionAdjustedGraphCenterY - drawingAmplitude
            let drawingAmplitudeDown = positionAdjustedGraphCenterY + drawingAmplitude
            
            if configuration.style == .striped && (Int(xPos) % 5 != 0) { continue }
            
            path.move(to: CGPoint(x: xPos, y: drawingAmplitudeUp))
            path.addLine(to: CGPoint(x: xPos, y: drawingAmplitudeDown))
        }
        context.addPath(path)
        
        switch configuration.style {
        case .filled, .striped:
            context.setStrokeColor(configuration.color.cgColor)
            context.strokePath()
        case .gradient:
            context.replacePathWithStrokedPath()
            context.clip()
            let colors = NSArray(array: [
                configuration.color.cgColor,
                configuration.color.highlighted(brightnessAdjustment: 0.5).cgColor
                ]) as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: nil)!
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: positionAdjustedGraphCenterY),
                                       end: CGPoint(x: 0, y: positionAdjustedGraphCenterY),
                                       options: .drawsAfterEndLocation)
        }
    }
}
