//
//  RecordingViewController.swift
//  VideoPipelineKit
//
//  Created by pat2man on 09/20/2017.
//  Copyright (c) 2017 pat2man. All rights reserved.
//

import UIKit
import VideoPipelineKit
import AVKit

class RecordingViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBAction func importPhoto(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary

        if #available(iOS 11.0, *) {
            picker.videoExportPreset = AVAssetExportPresetPassthrough
        }
        if let availableTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) {
            picker.mediaTypes = availableTypes
        }

        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    let captureSession = CaptureSession(renderPipeline: RenderPipeline(config: .defaultConfig, size: CGSize(width: 1080, height: 1920)))

    @IBAction func startRecording(_ sender: Any) {
        do {
            try captureSession.startRecording()
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    @IBOutlet weak var cameraView: UIView!

    @IBAction func stopRecording(_ sender: Any) {
        let outputURL = captureSession.outputURL
        captureSession.stopRecording {
            DispatchQueue.main.async {
                if let outputURL = outputURL {
                    let asset = AVURLAsset(url: outputURL)
                    let playerItem = AVPlayerItem(asset: asset)
                    self.performSegue(withIdentifier: "Edit Media", sender: playerItem)
                }
            }
        }
    }

    @IBAction func cancelEditing(_ sender: UIStoryboardSegue) {

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let previewLayer = captureSession.previewLayer {
            cameraView.layer.addSublayer(previewLayer)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        captureSession.previewLayer?.frame = cameraView.layer.bounds
        captureSession.isRunning = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession.isRunning = false
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let editingViewController = segue.destination as? MediaEditingViewController, let playerItem = sender as? AVPlayerItem {
            editingViewController.playerItem = playerItem
        }
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true) {
            if let url = info[UIImagePickerControllerMediaURL] as? URL {
                let asset = AVURLAsset(url: url)
                let playerItem = AVPlayerItem(asset: asset)
                self.performSegue(withIdentifier: "Edit Media", sender: playerItem)
            }
        }
    }
}

