//
//  ViewController.swift
//  ARKitVisionObjectDetection
//
//  Created by Dennis Ippel on 08/07/2020.
//  Copyright © 2020 Rozengain. All rights reserved.
//


import UIKit
import SceneKit
import ARKit
import Vision
import MultipeerConnectivity


class ViewController: UIViewController, ARSCNViewDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate {


    @IBOutlet var sceneView: ARSCNView!
    
    private var viewportSize: CGSize!
    private var detectKeyboardControl: Bool = true
    private var detectMouseControl: Bool = true
    private var detectCatControl: Bool = true
    
    
    
    
    var peerID:MCPeerID!
    var mcSession:MCSession!
    var mcAdvertiserAssistant:MCAdvertiserAssistant!
    

    
    override var shouldAutorotate: Bool { return false }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.autoenablesDefaultLighting = true
        sceneView.delegate = self
        
        viewportSize = sceneView.frame.size
        
                
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
    }
    
    
    @IBAction func showConnectivityAction(_ sender: Any) {

        var alertStyle = UIAlertController.Style.actionSheet
        if (UIDevice.current.userInterfaceIdiom == .pad) { alertStyle = UIAlertController.Style.alert }
        let actionSheet = UIAlertController(title: "Object Exchange", message: "Do you want to Host or Join a session?", preferredStyle: alertStyle)
        
        
//        let actionSheet = UIAlertController(title: "Object Exchange", message: "Do you want to Host or Join a session?", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Host Session", style: .default, handler: { (action:UIAlertAction) in
            
            self.mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "ba-td", discoveryInfo: nil, session: self.mcSession)
            self.mcAdvertiserAssistant.start()
            
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Join Session", style: .default, handler: { (action:UIAlertAction) in
            let mcBrowser = MCBrowserViewController(serviceType: "ba-td", session: self.mcSession)
            mcBrowser.delegate = self
            self.present(mcBrowser, animated: true, completion: nil)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        
        
        actionSheet.popoverPresentationController?.sourceView = self.view // works for both iPhone & iPad
        present(actionSheet, animated: true)
        { print("option menu presented") }


        
//        self.present(actionSheet, animated: true, completion: nil)
    }
    
    
    @IBAction func shareData(_ sender: Any) {
//        sendData(stringData: "keyboard")
//        print("sharing button")
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
        configuration.planeDetection = .horizontal
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        detectKeyboardControl = true
        detectMouseControl = true
        detectCatControl = true
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        
        
        var anchorName = ""
        anchorName = anchor.name!
        let index = anchorName.firstIndex(of: "A") ?? anchorName.endIndex
        guard anchorName[index] == "A" else { return }
//        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.01))
        
        var ObjectNode = SCNNode();
        
        if anchor.name=="keyboardAnchor" {
            guard let keyboardScene = SCNScene(named: "keyboard.scn"), let keyboardNode = keyboardScene.rootNode.childNode(withName: "keyboard", recursively: true) else { return }
            ObjectNode = keyboardNode
//            ObjectNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        }
        else if anchor.name=="mouseAnchor" {
            guard let paperPlaneScene = SCNScene(named: "mouse.scn"), let paperPlaneNode = paperPlaneScene.rootNode.childNode(withName: "mouse", recursively: true) else { return }
            ObjectNode = paperPlaneNode
//            ObjectNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        }
        else if anchor.name=="catAnchor" {
            guard let paperPlaneScene = SCNScene(named: "cat.scn"), let paperPlaneNode = paperPlaneScene.rootNode.childNode(withName: "cat", recursively: true) else { return }
            ObjectNode = paperPlaneNode
//            ObjectNode.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
        }
        
        
        
        node.addChildNode(ObjectNode)
    }
    

    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard detectKeyboardControl || detectMouseControl || detectCatControl ,
            let capturedImage = sceneView.session.currentFrame?.capturedImage
            else { return }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: capturedImage, orientation: .leftMirrored, options: [:])
        
        do {
//            if mcSession.connectedPeers.count > 0 {
                try imageRequestHandler.perform([objectDetectionRequest])
//            }
        } catch {
            print("Failed to perform image request.")
        }
    }
    
    lazy var objectDetectionRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: YOLOv3TinyInt8LUT().model)
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                if self?.detectKeyboardControl == true {                self?.processDetections(for: request, targetObject: "keyboard" ,error: error) }
                if self?.detectMouseControl == true {
                    self?.processDetections(for: request, targetObject: "mouse" ,error: error) }
                if self?.detectCatControl == true {
                    self?.processDetections(for: request, targetObject: "cat" ,error: error) }
            }
            return request
        } catch {
            fatalError("Failed to load Vision ML model.")
        }
    }()
    
    func processDetections(for request: VNRequest, targetObject: String ,error: Error?) {
        guard error == nil else {
            print("Object detection error: \(error!.localizedDescription)")
            return
        }
        
        guard let results = request.results else { return }
        
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation,
                let topLabelObservation = objectObservation.labels.first,
                topLabelObservation.identifier == targetObject,
                topLabelObservation.confidence > 0.5
                else { continue }
            
            guard let currentFrame = sceneView.session.currentFrame else { continue }
        
            // Get the affine transform to convert between normalized image coordinates and view coordinates
            let fromCameraImageToViewTransform = currentFrame.displayTransform(for: .portrait, viewportSize: viewportSize)
            // The observation's bounding box in normalized image coordinates
            let boundingBox = objectObservation.boundingBox
            // Transform the latter into normalized view coordinates
            let viewNormalizedBoundingBox = boundingBox.applying(fromCameraImageToViewTransform)
            // The affine transform for view coordinates
            let t = CGAffineTransform(scaleX: viewportSize.width, y: viewportSize.height)
            // Scale up to view coordinates
            let viewBoundingBox = viewNormalizedBoundingBox.applying(t)

            let midPoint = CGPoint(x: viewBoundingBox.midX,
                       y: viewBoundingBox.midY)

            let results = sceneView.hitTest(midPoint, types: .featurePoint)
            guard let result = results.first else { continue }

            let anchor = ARAnchor(name: targetObject + "Anchor" , transform: result.localTransform)
            sceneView.session.add(anchor: anchor)
            
            print(targetObject + " detected")
            if targetObject == "keyboard" {
                detectKeyboardControl = false
                print("done "+targetObject)
            }
            else if targetObject == "mouse" {
                detectMouseControl = false
            }
            else if targetObject == "cat" {
                detectCatControl = false
            }
            sendData(anchorData: anchor)
            print("ar anchor sent")
            
            

        }
    }
    
    @IBAction private func didTouchResetButton(_ sender: Any) {
        resetTracking()
    }
    
    
    func sendData(anchorData: ARAnchor) {
        print("sending data function")
        if mcSession.connectedPeers.count > 0
        {
//            if let message = stringData.data(using: String.Encoding.utf8, allowLossyConversion: false)
            
            if let message = try? NSKeyedArchiver.archivedData(withRootObject: anchorData, requiringSecureCoding: true)
            {
                do {
                    try mcSession.send(message, toPeers: mcSession.connectedPeers, with: .reliable)
                } catch let error as NSError {
                    let ac = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default))
                    present(ac, animated: true)
                }
            }
        }
    }
    
    
    //MARK:- MC Delegate Functions
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        switch state {
        case MCSessionState.connected:
            print("Connected: \(peerID.displayName)")
            
        case MCSessionState.connecting:
            print("Connecting: \(peerID.displayName)")
            
        case MCSessionState.notConnected:
            print("Not Connected: \(peerID.displayName)")
        @unknown default:
            fatalError("hi error")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
//        if let message = String(data: data, encoding: String.Encoding.utf8) {
//                DispatchQueue.main.async { [unowned self] in
//                    print(message)
//                }
//        }
        
        if let unarchievedData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
            print("recieved the AR anchor")
            sceneView.session.add(anchor: unarchievedData)
        }
        else{ print("could not recieve the ar anchor")}
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true, completion: nil)
    }
    
}
