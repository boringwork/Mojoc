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
 * Since : 2018-12-6
 * Update: 2019-1-28
 * Author: scott.cgi
 */


#ifndef DEVICE_INFO_H
#define DEVICE_INFO_H


#include <stdbool.h>


/**
 * Get system info in native platform.
 */
struct ASystemInfo
{
    /**
     * The outLanguageCode will be filled with an array of two characters.
     */
    void (*GetLanguageCode)(char outLanguageCode[2]);
};


extern struct ASystemInfo ASystemInfo[1];


#endif
