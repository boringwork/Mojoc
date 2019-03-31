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
 * The project Mojoc is a serious project with extreme code pursuit,
 * and will continue to iterate.
 *
 * Since : 2015-4-20
 * Update: 2019-1-23
 * Author: scott.cgi
 */


#ifndef SHADER_H
#define SHADER_H


#include "Engine/Graphics/OpenGL/Platform/gl3.h"


/**
 * Control shader.
 */
struct AShader
{
    /**
     * Record current using shader's program.
     */
    GLuint program;
};


extern struct AShader AShader[1];


#endif
