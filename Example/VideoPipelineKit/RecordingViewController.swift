//
//  RecordingViewController.swift
//  VideoPipelineKit
//
//  Created by pat2man on 09/20/2017.
//  Copyright (c) 2017 pat2man. All rights reserved.
//

import UIKit
import VideoPipelineKit
import CameraManager
import AVKit

class RecordingViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    lazy var cameraManager: CameraManager = {
        let cameraManager = CameraManager()
        cameraManager.cameraOutputMode = .videoOnly
        cameraManager.writeFilesToPhoneLibrary = false
        cameraManager.cameraDevice = .front
        cameraManager.showErrorBlock = { (erTitle: String, erMessage: String) in
            assertionFailure(erMessage)
        }
        return cameraManager
    }()

    @IBAction func importPhoto(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        if let availableTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) {
            picker.mediaTypes = availableTypes
        }
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    @IBAction func startRecording(_ sender: Any) {
        cameraManager.startRecordingVideo()
    }

    @IBOutlet weak var cameraView: UIView!

    @IBAction func stopRecording(_ sender: Any) {
        cameraManager.stopVideoRecording { (url, error) in
            if let error = error {
                assertionFailure(error.localizedDescription)
            }

            if let url = url {
                let asset = AVURLAsset(url: url)
                self.performSegue(withIdentifier: "Edit Media", sender: asset)
            }
        }
    }

    @IBAction func cancelEditing(_ sender: UIStoryboardSegue) {

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        _ = cameraManager.addPreviewLayerToView(cameraView)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let editingViewController = segue.destination as? MediaEditingViewController {
            editingViewController.asset = sender as? AVURLAsset
        }
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true) {
            if let url = info[UIImagePickerControllerMediaURL] as? URL {
                DispatchQueue.main.async {
                    let asset = AVURLAsset(url: url)
                    self.performSegue(withIdentifier: "Edit Media", sender: asset)
                }
            }
        }
    }
}

