//
//  Object.swift
//  Satin
//
//  Created by Reza Ali on 7/23/19.
//  Copyright © 2019 Reza Ali. All rights reserved.
//

import simd

open class Object: Codable {
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        position = try values.decode(simd_float3.self, forKey: .position)
        scale = try values.decode(simd_float3.self, forKey: .scale)
        orientation = try values.decode(simd_quatf.self, forKey: .orientation)
    }
    
    open func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(position, forKey: .position)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(scale, forKey: .scale)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case position
        case orientation
        case scale
    }
    
    public var id: String = UUID().uuidString
    public var label: String = "Object"
    
    var context: Context? {
        didSet {
            if context != nil {
                setup()
                if let context = self.context {
                    for child in children {
                        setupContext(context: context, object: child)
                    }
                }
            }
        }
    }
    
    func setupContext(context: Context, object: Object) {
        object.context = context
    }
    
    public var position = simd_make_float3(0, 0, 0) {
        didSet {
            updateMatrix = true
        }
    }
    
    public var orientation = simd_quaternion(0, simd_make_float3(0, 0, 1)) {
        didSet {
            updateMatrix = true
        }
    }
    
    public var scale = simd_make_float3(1, 1, 1) {
        didSet {
            updateMatrix = true
        }
    }
    
    public var translationMatrix: matrix_float4x4 {
        return Satin.translate(position)
    }
    
    public var scaleMatrix: matrix_float4x4 {
        return Satin.scale(scale)
    }
    
    public var rotationMatrix: matrix_float4x4 {
        return matrix_float4x4(orientation)
    }
    
    public var forwardDirection: simd_float3 {
        return simd_matrix3x3(orientation) * worldForwardDirection
    }
    
    public var upDirection: simd_float3 {
        return simd_matrix3x3(orientation) * worldUpDirection
    }
    
    public var rightDirection: simd_float3 {
        return simd_matrix3x3(orientation) * worldRightDirection
    }
    
    public weak var parent: Object? {
        didSet {
            updateMatrix = true
        }
    }
    
    public var children: [Object] = []
    
    public var onUpdate: (() -> ())?
    
    var updateMatrix: Bool = true {
        didSet {
            if updateMatrix {
                for child in children {
                    child.updateMatrix = true
                }
            }
        }
    }
    
    var _localMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    public var localMatrix: matrix_float4x4 {
        if updateMatrix {
            _localMatrix = simd_mul(simd_mul(translationMatrix, rotationMatrix), scaleMatrix)
            updateMatrix = false
        }
        return _localMatrix
    }
    
    var _worldPosition = simd_make_float3(0, 0, 0)
    
    public var worldPosition: simd_float3 {
        if updateMatrix {
            let wp = worldMatrix.columns.3
            _worldPosition = simd_make_float3(wp.x, wp.y, wp.z)
            return _worldPosition
        }
        else {
            return _worldPosition
        }
    }
    
    var _worldScale = simd_make_float3(0, 0, 0)
    
    public var worldScale: simd_float3 {
        if updateMatrix {
            let wm = worldMatrix
            let sx = wm.columns.0
            let sy = wm.columns.1
            let sz = wm.columns.2
            _worldScale = simd_make_float3(length(sx), length(sy), length(sz))
            return _worldScale
        }
        else
        {
            return _worldScale
        }
    }

    var _worldOrientation = simd_quaternion(0, simd_make_float3(0, 0, 1))
    
    private var worldOrientation: simd_quatf {
        if updateMatrix {
            let ws = worldScale
            let wm = worldMatrix
            let c0 = wm.columns.0
            let c1 = wm.columns.0
            let c2 = wm.columns.0
            let x = simd_make_float3(c0.x, c0.y, c0.z)/ws.x
            let y = simd_make_float3(c1.x, c1.y, c1.z)/ws.y
            let z = simd_make_float3(c2.x, c2.y, c2.z)/ws.z
            _worldOrientation = simd_quatf(simd_float3x3(columns: (x, y, z)))
            return _worldOrientation
        }
        else {
            return _worldOrientation
        }
    }
    
    var _worldMatrix: matrix_float4x4 = matrix_identity_float4x4
    
    public var worldMatrix: matrix_float4x4 {
        if updateMatrix {
            if let parent = self.parent {
                _worldMatrix = simd_mul(parent.worldMatrix, localMatrix)
            } else {
                _worldMatrix = localMatrix
            }
            updateMatrix = false
        }
        return _worldMatrix
    }
    
    public init() {}
    
    func setup() {}
    
    public func update() {
        onUpdate?()
        
        for child in children {
            child.update()
        }
    }
    
    public func add(_ child: Object) {
        if !children.contains(child) {
            child.parent = self
            child.context = context
            children.append(child)
        }
    }
    
    public func remove(_ child: Object) {
        for (index, object) in children.enumerated() {
            if object == child {
                children.remove(at: index)
                return
            }
        }
    }
}

extension Object: Equatable {
    public static func == (lhs: Object, rhs: Object) -> Bool {
        return lhs.id == rhs.id
    }
}
