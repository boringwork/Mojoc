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
 * Since : 2014-6-3
 * Update: 2019-1-18
 * Author: scott.cgi
 */


#ifndef PHYSICS_BODY_H
#define PHYSICS_BODY_H


#include "Engine/Toolkit/Math/Matrix.h"
#include "Engine/Toolkit/HeaderUtils/Bitwise.h"
#include "Engine/Toolkit/Utils/Array.h"
#include "Engine/Toolkit/HeaderUtils/UserData.h"


typedef enum
{
    PhysicsShape_NULL    = 0,
    PhysicsShape_Polygon = 1,
    PhysicsShape_Line    = 1 << 2, // NOLINT(hicpp-signed-bitwise)
    PhysicsShape_Point   = 1 << 3, // NOLINT(hicpp-signed-bitwise)
}
PhysicsShape;


typedef enum
{
    /**
     * Not add in physics world yet.
     */
    PhysicsBodyState_OutsideWorld,

    /**
     * Can motion can collision.
     */
    PhysicsBodyState_Normal,

    /**
     * No motion can collision.
     */
    PhysicsBodyState_Fixed,

    /**
     * No motion no collision.
     */
    PhysicsBodyState_Freeze,
}
PhysicsBodyState;


typedef struct PhysicsBody PhysicsBody;
struct  PhysicsBody
{
    UserData         userData[1];

    /**
     * Used to identify PhysicsBody, default -1.
     */
    int              userId;

    float            positionX;
    float            positionY;
    float            velocityX;
    float            velocityY;
    float            accelerationX;
    float            accelerationY;
    float            rotationZ;

    PhysicsShape     shape;

    /**
     * PhysicsBody current state.
     */
    PhysicsBodyState state;

    /**
     * Pow of 2, default 0.
     * body can collision between different collisionGroup (no same bit).
     */
    int              collisionGroup;

    /**
     * Store born vertices.
     */
    Array(float)     vertexArr[1];

    /**
     * The vertices after transformed.
     */
    Array(float)     transformedVertexArr[1];

    /**
     * When body collision callback.
     */
    void (*OnCollision)(PhysicsBody* self, PhysicsBody* other, float deltaSeconds);
};


/**
 * Control PhysicsBody.
 */
struct APhysicsBody
{
    /**
     * Create body with shape and vertices.
     *
     * the vertexArr will copy into body,
     * and the body's vertexArr and transformedVertexArr are same when init,
     * and all data create by one malloc.
     *
     * if shape not support will return NULL.
     */
    PhysicsBody* (*Create)       (PhysicsShape shape, Array(float)* vertexArr);

    /**
     * Reset body's transformedVertexArr to vertexArr.
     */
    void         (*ResetVertices)(PhysicsBody* body);

    /**
     * Simulate body motion and update transformedVertexArr by position, rotation.
     */
    void         (*Update)       (PhysicsBody* body, float deltaSeconds);

};


extern struct APhysicsBody APhysicsBody[1];


//----------------------------------------------------------------------------------------------------------------------


/**
 *  Check physicsBody whether has same bit in collisionGroup.
 */
static inline bool APhysicsBody_CheckCollisionGroup(PhysicsBody* physicsBody, int collisionGroup)
{
    return ABitwise_Check(physicsBody->collisionGroup, collisionGroup); // NOLINT(hicpp-signed-bitwise)
}


/**
 * Add collisionGroup to physicsBody.
 */
static inline void APhysicsBody_AddCollisionGroup(PhysicsBody* physicsBody, int collisionGroup)
{
    ABitwise_Add(physicsBody->collisionGroup, collisionGroup); // NOLINT(hicpp-signed-bitwise)
}


/**
 * Set collisionGroup to physicsBody.
 */
static inline void APhysicsBody_SetCollisionGroup(PhysicsBody* physicsBody, int collisionGroup)
{
    ABitwise_Set(physicsBody->collisionGroup, collisionGroup);
}


/**
 * Clear collisionGroup in physicsBody.
 */
static inline void APhysicsBody_ClearCollisionGroup(PhysicsBody* physicsBody, int collisionGroup)
{
    ABitwise_Clear(physicsBody->collisionGroup, collisionGroup);  // NOLINT(hicpp-signed-bitwise)
}


#endif
