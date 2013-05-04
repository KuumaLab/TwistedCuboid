//
//  Shader.vsh
//  TwistedCuboid
//
//  Created by KuumaLab on 5/3/13.
//  Copyright (c) 2013 kuuma Production. All rights reserved.
//

attribute vec4 position;
attribute vec3 normal;

varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;
uniform float twistAngle;


vec3 rotateX(vec3 vertices, float cos_value, float sin_value){
    
    float y = vertices.y * cos_value - vertices.z * sin_value;
    float z = vertices.y * sin_value + vertices.z * cos_value;
    
    return vec3(vertices.x, y, z);
}

void main()
{
    float ratio = (position.x + 1.0)/2.0;
    float angle = twistAngle * ratio;
    float cos_value = cos(angle);
    float sin_value = sin(angle);
    
    vec3 convertedPosition = rotateX(position.xyz, cos_value, sin_value);
    
    vec3 convertedNormal = rotateX(normal, cos_value, sin_value);

    vec3 eyeNormal = normalize(normalMatrix * convertedNormal);
    vec3 lightPosition = vec3(0.0, 0.0, 1.0);
    vec4 diffuseColor = vec4(0.4, 0.4, 1.0, 1.0);
    
    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
                 
    colorVarying = diffuseColor * nDotVP;
    
    gl_Position = modelViewProjectionMatrix * vec4(convertedPosition, position.w);
}
