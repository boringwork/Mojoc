/*
 * Copyright (c) 2012-2019 scott.cgi All Rights Reserved.
 *
 * This source code is licensed under the MIT License,
 * and the license can be found at: https://github.com/scottcgi/Mojoc/blob/master/LICENSE
 *
 * This source code belongs to project Mojoc which is a pure C game engine hosted on GitHub,
 * and the details can be found at: https://github.com/scottcgi/Mojoc
 *
 * The author information can be found at:
 * https://github.com/scottcgi
 *
 * The Mojoc game engine is a serious project with extreme code pursuit,
 * and will continue to iterate.
 *
 * Since : 2016-8-13
 * Update: 2019-1-24
 * Author: scott.cgi
 */


#ifndef SHADER_MESH_H
#define SHADER_MESH_H


#include "Engine/Graphics/OpenGL/Platform/gl3.h"
#include "Engine/Toolkit/Math/Matrix.h"
#include "Engine/Toolkit/Math/Math.h"


/**
 * Shader control for Mesh.
 */
struct AShaderMesh
{
    GLuint program;
    GLint  attribPosition;
    GLint  attribTexcoord;
    GLint  attribOpacity;
    GLint  attribRGB;

    GLint  uniformMVPMatrix;
    GLint  uniformSample2D;

    void (*Use) (Matrix4* mvpMatrix);
    void (*Init)(void);
};


extern struct AShaderMesh AShaderMesh[1];


#endif
