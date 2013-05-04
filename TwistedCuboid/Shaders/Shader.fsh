//
//  Shader.fsh
//  TwistedCuboid
//
//  Created by Tanaka Ryuta on 5/4/13.
//  Copyright (c) 2013 kuuma Production. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
