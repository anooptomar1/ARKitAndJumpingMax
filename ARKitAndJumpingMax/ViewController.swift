//
//  ViewController.swift
//  ARKitAndJumpingMax
//
//  Created by magicien on 2017/06/07.
//  Copyright © 2017年 DarkHorse. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var anchorNode: SCNNode?
    let parentNode = SCNNode()
    var panda: SCNNode!
    var pandas = [SCNNode]()
    var lightNode: SCNNode!
    var ambientLightNode: SCNNode!
    var planeNode: SCNNode!
    
    let holeDepth: CGFloat = 0.5
    let holeRadius: CGFloat = 0.1
    
    let customShader = """
        #pragma arguments

            float holeRadius;

        #pragma body
            float4 p = scn_node.modelViewTransform * float4(0, 0, 0, 1);
            if(distance(_surface.position, p.xyz) < holeRadius){
                discard_fragment();
            }
    """
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // create and add lights to the scene
        lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .directional
        lightNode.light!.castsShadow = true
//        lightNode.light!.shadowMode = .deferred
        lightNode.rotation = SCNVector4(1.0, 0.0, 0.0, -0.5 * Double.pi)
        scene.rootNode.addChildNode(lightNode)
        
        ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        panda = SCNScene(named: "art.scnassets/panda.scn")!.rootNode.childNodes[0]
        panda.scale = SCNVector3(0.5, 0.5, 0.5)
        panda.position = SCNVector3(0, -holeDepth, 0)
        panda.enumerateChildNodes { (child, _) in
            for key in child.animationKeys {                  // for every animation key
                let animation = child.animation(forKey: key)! // get the animation
                animation.usesSceneTimeBase = false           // make it system time based
                animation.repeatCount = Float.infinity        // make it repeat forever
                child.addAnimation(animation, forKey: key)             // animations are copied upon addition, so we have to replace the previous animation
            }
        }
        for i in 0..<4 {
            let newPanda = panda.clone()
            newPanda.rotation = SCNVector4(0, 1, 0, Float.pi * Float(i) * 0.5)
            pandas.append(newPanda)
        }
        
        
        let planeGeometry = SCNPlane()
        planeGeometry.shaderModifiers = [ SCNShaderModifierEntryPoint.fragment: customShader ]
        planeGeometry.firstMaterial?.colorBufferWriteMask = SCNColorMask.init(rawValue: 0)
        planeGeometry.firstMaterial?.setValue(0.0, forKey: "holeRadius")
        planeGeometry.firstMaterial?.isDoubleSided = true
        
        planeNode = SCNNode(geometry: planeGeometry)
        planeNode.rotation = SCNVector4(1.0, 0.0, 0.0, -Float.pi * 0.5)
        planeNode.castsShadow = false
        
        let cylinder = SCNCylinder(radius: holeRadius, height: holeDepth)
        cylinder.firstMaterial?.diffuse.contents = SKColor.darkGray
        cylinder.firstMaterial?.cullMode = .front
        let cylinderNode = SCNNode(geometry: cylinder)
        cylinderNode.position = SCNVector3(0, -holeDepth * 0.5, 0)
        cylinderNode.castsShadow = false
        
        let offset: CGFloat = 0.01
        let box = SCNBox(width: (holeRadius + offset) * 2.0, height: holeDepth + offset, length: (holeRadius + offset) * 2.0, chamferRadius: 0)
        let boxMaterial1 = SCNMaterial()
        boxMaterial1.colorBufferWriteMask = SCNColorMask.init(rawValue: 0)
        boxMaterial1.writesToDepthBuffer = true
        let boxMaterial2 = SCNMaterial()
        boxMaterial2.transparency = 0
        boxMaterial2.diffuse.contents = SKColor.red
        
        box.materials = [
            boxMaterial1, boxMaterial1, boxMaterial1, boxMaterial1, boxMaterial2, boxMaterial1
        ]
        let magicBox = SCNNode(geometry: box)
        magicBox.position.y = -Float(holeDepth + offset) * 0.5
        
        for i in 0..<4 {
            parentNode.addChildNode(pandas[i])
        }
        parentNode.addChildNode(panda)
        parentNode.addChildNode(planeNode)
        parentNode.addChildNode(cylinderNode)
        parentNode.addChildNode(magicBox)
        
        planeNode.renderingOrder = 0
        for p in pandas {
            p.renderingOrder = 1
        }
        magicBox.renderingOrder = 2
        panda.renderingOrder = 3
        cylinderNode.renderingOrder = 4
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    func updatePosition(anchor: ARPlaneAnchor) {
        anchorNode?.simdTransform = anchor.transform
        
        guard let plane = planeNode.geometry as? SCNPlane else { return }
        plane.width = CGFloat(anchor.extent.x)
        plane.height = CGFloat(anchor.extent.z)
        let position = SCNVector3(anchor.center)
        parentNode.position = position
        
        let margin: Float = 0.1
        let width = anchor.extent.x * 0.5 + margin
        let length = anchor.extent.z * 0.5 + margin
        pandas[0].position.z = -length
        pandas[1].position.x = -width
        pandas[2].position.z = length
        pandas[3].position.x = width
    }
    
    func startJumping() {
        let jumpHeight: CGFloat = 0.5
        let jumpDuration: TimeInterval = 0.35
        let goUp = SCNAction.moveBy(x: 0, y: jumpHeight, z: 0, duration: jumpDuration)
        goUp.timingMode = .easeOut
        let goDown = goUp.reversed()
        goDown.timingMode = .easeIn
        
        let jump = SCNAction.repeatForever(SCNAction.sequence([goUp, goDown]))
        panda.runAction(jump)
        let timeOffset = jumpDuration * 0.2
        for i in 0..<4 {
            pandas[i].runAction(SCNAction.sequence([SCNAction.wait(duration: timeOffset * Double(i + 1)), jump]))
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchorNode == nil else {
            return nil
        }
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return nil
        }
        
        let node = SCNNode()
        node.simdTransform = planeAnchor.transform
        
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        sceneView.scene.rootNode.addChildNode(node)
        
        if anchorNode == nil {
            anchorNode = node
            
            parentNode.removeFromParentNode()
            node.addChildNode(parentNode)
            
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
            updatePosition(anchor: planeAnchor)
            
            let actionDuration = 3.0
            let createHoleAction = SCNAction.customAction(duration: actionDuration, action: { (node, time) in
                let h = Double(self.holeRadius * time) / actionDuration
                node.geometry?.firstMaterial?.setValue(h, forKey: "holeRadius")
            })
            
            planeNode.runAction(createHoleAction, completionHandler: {
                self.planeNode.geometry?.firstMaterial?.setValue(self.holeRadius, forKey: "holeRadius")
                self.startJumping()
            })
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if node == anchorNode {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
            updatePosition(anchor: planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        if node == anchorNode {
            anchorNode = nil
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let lightEstimate = self.sceneView.session.currentFrame?.lightEstimate else { return }
        let intensity = lightEstimate.ambientIntensity
        lightNode.light!.intensity = intensity
        ambientLightNode.light!.intensity = intensity
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
