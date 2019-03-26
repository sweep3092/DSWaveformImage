import Foundation
import UIKit

public class CircularWaveformImageDrawer: ImageDrawer {
    public init() {}
    
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

private extension CircularWaveformImageDrawer {
    func render(waveform: Waveform, with configuration: WaveformConfiguration) -> UIImage? {
        let sampleCount = Int(configuration.size.width * configuration.scale)
        guard let analysis = waveform.analysis(count: sampleCount) else { return nil }
        return graphImage(from: analysis, with: configuration)
    }
    
    func graphImage(from analysis: WaveformAnalysis, with configuration: WaveformConfiguration) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(configuration.size, false, configuration.scale)
        let context = UIGraphicsGetCurrentContext()!
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        
        drawBackground(on: context, with: configuration)
        drawGraph(from: analysis, on: context, with: configuration)
        
        let graphImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return graphImage
    }
    
    func drawBackground(on context: CGContext, with configuration: WaveformConfiguration) {
        context.setFillColor(configuration.backgroundColor.cgColor)
        context.fill(CGRect(origin: CGPoint.zero, size: configuration.size))
    }
    
    func drawGraph(from analysis: WaveformAnalysis,
                   on context: CGContext,
                   with configuration: WaveformConfiguration) {
        // TODO: do not do normalization here
        // TODO: normalize over ALL FFTs
        // TODO: also, update to dB AND consider we have negative db!
        var maxValue: Float = 0.0
        var samples = analysis.fft!.map { (fft: FFTResult) -> [Float] in
            var dbs = [Float]()
            for i in 0..<fft.magnitudes.count {
                let dB = TempiFFT.toDB(abs(fft.magnitudes[i]))
                dbs.append(dB)
                maxValue = max(maxValue, dB)
            }
            return dbs
        }
        samples = samples.map { (fft: [Float]) -> [Float] in
            return fft.map { value in
                value / maxValue
            }
        }
        
        let maximumDrawRadius: CGFloat = 80.0
        let minimumGraphAmplitude: CGFloat = 1 // we want to see at least a 1pt line for silence
        
        let path = CGMutablePath()
        context.setLineWidth(1.0 * configuration.scale)
        
//        print("rows: \(samples.count) for \(configuration.size.height) point = \(configuration.size.height * configuration.scale)px")
        
        for (y, yRow) in samples.enumerated() {
            print("\(yRow.count) columns")
            let yPos = CGFloat(y) * 10
            for (x, sample) in yRow.enumerated() {
                let xPos = CGFloat(x)// / configuration.scale
                let invertedDbSample = 1 - CGFloat(sample) // sample is in dB, linearly normalized to [0, 1] (1 -> -50 dB)
                let drawingAmplitude = max(minimumGraphAmplitude, invertedDbSample * maximumDrawRadius)
                
                if configuration.style == .striped && (Int(xPos) % 5 != 0) { continue }
                
                if x % 50 == 0 {
                    path.move(to: CGPoint(x: xPos + 1, y: yPos))
                    path.addArc(center: CGPoint(x: xPos, y: yPos), radius: 1, startAngle: 0, endAngle: CGFloat(Float.pi), clockwise: true, transform: CGAffineTransform.identity)
                    path.move(to: CGPoint(x: xPos + drawingAmplitude, y: yPos))
                    path.addArc(center: CGPoint(x: xPos, y: yPos), radius: drawingAmplitude, startAngle: 0, endAngle: CGFloat(Float.pi), clockwise: true, transform: CGAffineTransform.identity)
                }
            }
        }
        context.addPath(path)
        context.setStrokeColor(configuration.color.cgColor)
        context.strokePath()
    }
}
