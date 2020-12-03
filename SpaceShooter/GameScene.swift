//
//  GameScene.swift
//  SpaceShooter
//
//  Created by Md. Kamrul Hasan on 3/12/20.
//

import SpriteKit
import GameplayKit
import CoreMotion

class GameScene: SKScene {
    
    var starfield: SKEmitterNode!
    var player: SKSpriteNode!
    
    var scoreLabel: SKLabelNode!
    var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    var alienTimer: Timer!
    var possibleAliens = ["alien", "alien2", "alien3"]
    
    let alienCategory: UInt32 = 0x1 << 1
    let photonTorpedoCategory: UInt32 = 0x1 << 0
    
    var motionManager = CMMotionManager()
    var xAcceleration: CGFloat = 0
    
    override func didMove(to view: SKView) {
        starfield = SKEmitterNode(fileNamed: "Starfield")
        starfield.position = CGPoint(x: 0, y: self.frame.size.height)
        starfield.advanceSimulationTime(10)
        self.addChild(starfield)
        
        starfield.zPosition = -1
        
        player = SKSpriteNode(imageNamed: "shuttle")
        player.position = CGPoint(x: 0, y: -frame.size.height/2.5)
        self.addChild(player)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self
        
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.position = CGPoint(x: -frame.size.width/2.5, y: frame.size.height/2.5)
        scoreLabel.fontName = "AmericanTypeWriter-Bold"
        scoreLabel.fontSize = 36
        scoreLabel.fontColor = .white
        score = 0
        addChild(scoreLabel)
        
        alienTimer = Timer.scheduledTimer(timeInterval: 0.75, target: self, selector: #selector(addAlien), userInfo: nil, repeats: true)
        
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { (data: CMAccelerometerData?, error: Error?) in
            guard let accelerationData = data else { return }
            let acceleration = accelerationData.acceleration
            self.xAcceleration = CGFloat(acceleration.x) * 5 + self.xAcceleration * 0.55
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
    
    //
    @objc func addAlien() {
        possibleAliens = GKRandomSource.sharedRandom().arrayByShufflingObjects(in: possibleAliens) as! [String]
        let alien = SKSpriteNode(imageNamed: possibleAliens.randomElement() ?? possibleAliens[0])
        let randomAlienPosition = GKRandomDistribution(lowestValue: -Int(frame.size.width/2.5), highestValue: Int(frame.size.width/2.5))
        let position = CGFloat(randomAlienPosition.nextInt())
        
        alien.position = CGPoint(x: position, y: frame.size.height/2.5 + alien.size.height)
        alien.physicsBody = SKPhysicsBody(rectangleOf: alien.size)
        alien.physicsBody?.isDynamic = true
        
        alien.physicsBody?.categoryBitMask = alienCategory
        alien.physicsBody?.contactTestBitMask = photonTorpedoCategory
        alien.physicsBody?.collisionBitMask = 0
        
        addChild(alien)
        
        let animationDuration: TimeInterval = 6
        var actionArray = [SKAction]()
    
        actionArray.append(SKAction.move(to: CGPoint(x: position, y: -frame.size.height/2.5), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        
        alien.run(SKAction.sequence(actionArray))
                           
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fireTorpedo()
    }
    
    func fireTorpedo() {
        let torpedoNode = SKSpriteNode(imageNamed: "torpedo")
        torpedoNode.position = player.position
        torpedoNode.position.y = player.position.y-5
        
        torpedoNode.physicsBody = SKPhysicsBody(circleOfRadius: torpedoNode.size.width/2)
        torpedoNode.physicsBody?.isDynamic = true
        
        torpedoNode.physicsBody?.categoryBitMask = photonTorpedoCategory
        torpedoNode.physicsBody?.contactTestBitMask = alienCategory
        torpedoNode.physicsBody?.collisionBitMask = 0
        torpedoNode.physicsBody?.usesPreciseCollisionDetection = true
        
        addChild(torpedoNode)
        
        let animationDuration: TimeInterval = 0.5
        var actionArray = [SKAction]()
        
        actionArray.append(SKAction.move(to: CGPoint(x: player.position.x, y: frame.size.height), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        
        torpedoNode.run(SKAction.sequence(actionArray))
        
        run(SKAction.playSoundFileNamed("torpedo.mp3", waitForCompletion: false))
    }
    
    func torpedoDidCollisionWithAlien(torpedoNode: SKSpriteNode, alienNode: SKSpriteNode) {
        guard let explosionNode = SKEmitterNode(fileNamed: "Explosion") else { return }
        explosionNode.position = alienNode.position
        addChild(explosionNode)
        
        run(SKAction.playSoundFileNamed("explosion.mp3", waitForCompletion: false))
        
        torpedoNode.removeFromParent()
        alienNode.removeFromParent()
        
        run(SKAction.wait(forDuration: 2)) {
            explosionNode.removeFromParent()
        }
        
        score = score + 5
    }
    
    override func didSimulatePhysics() {
        player.position.x = xAcceleration * 50
                
        if player.position.x < -size.width/2.5 - 20 {
            player.position = CGPoint(x: size.width/2.5 + 20, y: player.position.y)
        } else if player.position.x > (size.width/2.5 + 20) {
            player.position = CGPoint(x: -size.width/2.5 - 20, y: player.position.y)
        }
    }
}

extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        if (firstBody.categoryBitMask & photonTorpedoCategory) != 0 && (secondBody.categoryBitMask & alienCategory) != 0 {
            guard let torpedo = firstBody.node as? SKSpriteNode, let alien = secondBody.node as? SKSpriteNode else { return }
            torpedoDidCollisionWithAlien(torpedoNode: torpedo, alienNode: alien)
        }
    }
}
