//
//  ViewController.m
//  Template
//
//  Created by KuumaLab on 5/4/13.
//  Copyright (c) 2013 __KuumaLab__. All rights reserved.
//

#import "ViewController.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_TWIST_ANGLE,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};

@interface ViewController () {
    GLuint _program;
    
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    float _rotation;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    GLuint _vertexIndices;
    int _indicesNum;
    
    CGPoint _touch_point;
    float _twistAngle;
    BOOL _touchEnded;
}
@property (strong, nonatomic) EAGLContext *context;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation ViewController

@synthesize context = _context;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    _twistAngle = 0.0;
    _touchEnded = NO;
    
    [self setupGL];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
	self.context = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc. that aren't in use.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    glEnable(GL_DEPTH_TEST);
    
    int divisionLevelLength = 128;
    int divisionLevelRound = 8;
    int size = sizeof(GLfloat) * divisionLevelLength * divisionLevelRound * 2 * (3 + 3) ;
    GLfloat *array = (GLfloat *)malloc(size);
    
    int index=0;
    float diameter = 1.0;
    float length = 3.0;
    for (int j=0; j<divisionLevelRound; j++) {
        
        float degree1 = GLKMathDegreesToRadians(j * 360/divisionLevelRound);
        float degree2 = GLKMathDegreesToRadians((j+1) * 360/divisionLevelRound);
        
        float sin_degree1 = sinf(degree1);
        float cos_degree1 = cosf(degree1);
        float sin_degree2 = sinf(degree2);
        float cos_degree2 = cosf(degree2);
        
        float normalDegree = GLKMathDegreesToRadians(j * 360.0/divisionLevelRound + 360.0/(2.0*divisionLevelRound));
        float sin_normalDegree = sinf(normalDegree);
        float cos_normalDegree = cosf(normalDegree);
        
        for (int i=0; i<divisionLevelLength; i++) {
            
            //vertices
            array[index  ] = -length/4.0 + i*length/(float)divisionLevelLength;
            array[index+1] = diameter/2.0 * sin_degree1;
            array[index+2] = diameter/2.0 * cos_degree1;
            
            array[index+6] = -length/4.0 + i*length/(float)divisionLevelLength;
            array[index+7] = diameter/2.0 * sin_degree2;
            array[index+8] = diameter/2.0 * cos_degree2;
            
            if( j==0) NSLog(@"%f", array[index]);
            
            //normal
            array[index+3] = 0.0;
            array[index+4] = sin_normalDegree;
            array[index+5] = cos_normalDegree;
            
            array[index+9] = 0.0;
            array[index+10] = sin_normalDegree;
            array[index+11] = cos_normalDegree;
            
            index +=12;
        }
    }
    
    ////////////INDICES///////////
    _indicesNum = (divisionLevelLength-1) * divisionLevelRound * 3 * 2;
    int sizeOfIndices = sizeof(GLshort) * _indicesNum;
    GLshort *indices = (GLshort *)malloc(sizeOfIndices);
    index = 0;
    for (int i=0; i<divisionLevelRound; i++) {
        
        int l = i*(divisionLevelLength * 2);
        
        for (int j=0; j<(divisionLevelLength-1); j++) {
            indices[index  ] = l+j;
            indices[index+1] = l+j+1;
            indices[index+2] = l+j+2;
            
            indices[index+3] = l+j+1;
            indices[index+4] = l+j+2;
            indices[index+5] = l+j+3;
            
            index +=6;
        }
    }
    
    //////////Indices Buffer/////////
    glGenBuffers(1, &_vertexIndices);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _vertexIndices);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeOfIndices, indices, GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    
    ///////
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, size, array, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 24, (GLvoid*)(sizeof(GLfloat) * 0));
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 24, (GLvoid*)(sizeof(GLfloat) * 3));
    
    glBindVertexArrayOES(0);
    
    free(array);
    free(indices);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    //self.effect.transform.projectionMatrix = projectionMatrix;
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -2.0f);
    //baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, _rotation, 0.0f, 1.0f, 0.0f);
    
    
    
    // Compute the model view matrix for the object rendered with ES2
    GLKMatrix4 modelViewMatrix;
    //modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 0.0f);
    modelViewMatrix = GLKMatrix4MakeRotation(_rotation, 10.0f, 0.0f, 0.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    _rotation += self.timeSinceLastUpdate * 0.5;
    
    if (_touchEnded && _twistAngle > 0.0) {
        _twistAngle -= self.timeSinceLastUpdate * 3.0 * 2.0 * M_PI;
        _twistAngle = (_twistAngle < 0.0) ? 0.0 : _twistAngle;
    };
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArray);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    glUniform1f(uniforms[UNIFORM_TWIST_ANGLE], _twistAngle);
    
    //glDrawArrays(GL_TRIANGLES, 0, 36);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _vertexIndices);
    glDrawElements(GL_TRIANGLES, _indicesNum, GL_UNSIGNED_SHORT, 0);
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIB_NORMAL, "normal");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    uniforms[UNIFORM_TWIST_ANGLE] = glGetUniformLocation(_program, "twistAngle");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    /////////////////////////////////////////////////////////
    ///////     CHECKING IF BUTTON IS PRESSED      //////////
    /////////////////////////////////////////////////////////
    for (UITouch *touch in touches) {
		_touch_point = [touch locationInView:self.view];
    }
    
    _touchEnded = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    //NSLog(@"touch ended");
    _touchEnded = YES;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"touch cancelled");
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    for (UITouch *touch in touches) {
		CGPoint currentLocation = [touch locationInView:self.view];
        CGPoint previousLocation = _touch_point;//[touch previousLocationInView:self.view];
        
        
        CGFloat y = previousLocation.y - currentLocation.y;
        _twistAngle = 3.0 * 2.0 * M_PI * y/self.view.bounds.size.height;
        NSLog(@"height %f", self.view.bounds.size.height);
        
    }
}

@end
