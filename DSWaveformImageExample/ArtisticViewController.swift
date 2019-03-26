//
//  ArtisticViewController.swift
//  DSWaveformImageExample
//
//  Created by Dennis Schmidt on 3/26/19.
//  Copyright © 2019 Dennis Schmidt. All rights reserved.
//

import UIKit
import DSWaveformImage

class ArtisticViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        super.viewDidLoad()
        
        let waveformImageDrawer = CircularWaveformImageDrawer()
        let audioURL = Bundle.main.url(forResource: "example_sound_2", withExtension: "m4a")!

        // uses background thread rendering
        let waveform = Waveform(audioAssetURL: audioURL)!
        let configuration = WaveformConfiguration(size: imageView.bounds.size,
                                                  color: UIColor.blue,
                                                  style: .filled,
                                                  position: .bottom)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let image = waveformImageDrawer.waveformImage(from: waveform, with: configuration)
            DispatchQueue.main.async {
                self.imageView.image = image
            }
        }
    }
    
}
