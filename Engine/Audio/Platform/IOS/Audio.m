/*
 * Copyright (c) 2012-2019 scott.cgi All Rights Reserved.
 *
 * This code and its project Mojoc are licensed under [the MIT License],
 * and the project Mojoc is a game engine hosted on github at [https://github.com/scottcgi/Mojoc],
 * and the author's personal website is [https://scottcgi.github.io],
 * and the author's email is [scott.cgi@qq.com].
 *
 * Since : 2017-5-4
 * Update: 2019-1-7
 * Author: scott.cgi
 */


#include "Engine/Toolkit/Platform/Platform.h"


#ifdef IS_PLATFORM_IOS


#include <stddef.h>
#include <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#include <OpenAL/OpenAL.h>

#include "Engine/Audio/Platform/Audio.h"
#include "Engine/Toolkit/Platform/Log.h"
#include "Engine/Toolkit/Utils/ArrayStrMap.h"
#include "Engine/Toolkit/Utils/ArrayStrSet.h"


static ArrayStrMap(filePath, void*) fileDataMap[1] = AArrayStrMap_Init(void*,        20);
static ArrayList  (AudioPlayer*)    cacheList  [1] = AArrayList_Init  (AudioPlayer*, 20);
static ArrayList  (AudioPlayer*)    destroyList[1] = AArrayList_Init  (AudioPlayer*, 20);
static ArrayList  (AudioPlayer*)    loopList   [1] = AArrayList_Init  (AudioPlayer*, 5 );
static ArrayStrSet(filePath)        filePathSet[1] = ArrayStrSet_Init (filePath,     20);


#define CheckAudioDataError(tag)               \
    ALog_A                                     \
    (                                          \
        error == noErr,                        \
        "AAudio GetAudioData " tag " failed, " \
        "OSStatus error = %x, file path = %s", \
        (int) error,                           \
        relativeFilePath                       \
    )

#define CheckAudioError(tag, filePath)        \
    ALog_A                                    \
    (                                         \
        (error = alGetError()) == AL_NO_ERROR,\
        "AAudio " tag " failed, "             \
        "alGetError = %x, file path = %s",    \
        error,                                \
        filePath                              \
    )


static inline void* GetAudioData
(
    const char* relativeFilePath,
    ALsizei*    outDataSize,
    ALenum*     outDataFormat,
    ALsizei*    outSampleRate
)
{
    AudioStreamBasicDescription fileFormat;
    AudioStreamBasicDescription outputFormat;

    SInt64          fileLengthInFrames = 0;
    UInt32          propertySize       = sizeof(fileFormat);
    ExtAudioFileRef audioFileRef       = NULL;
    void*           data               = NULL;
    NSString*       path               = [[NSBundle mainBundle] pathForResource:
                                         [NSString stringWithUTF8String:relativeFilePath] ofType:nil];

    CFURLRef        fileUrl            = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef) path, NULL);
    OSStatus        error              = ExtAudioFileOpenURL(fileUrl, &audioFileRef);
    CheckAudioDataError("ExtAudioFileOpenURL");

    CFRelease(fileUrl);
    
    // get the audio data format
    error = ExtAudioFileGetProperty(audioFileRef, kExtAudioFileProperty_FileDataFormat, &propertySize, &fileFormat);
    CheckAudioDataError("ExtAudioFileGetProperty kExtAudioFileProperty_FileDataFormat");

    if (fileFormat.mChannelsPerFrame > 2)
    {
        ALog_E
        (
            "AAudio GetAudioData unsupported format,"
            "channel count = %u is greater than stereo, relativeFilePath = %s",
            (unsigned int) fileFormat.mChannelsPerFrame,
            relativeFilePath
        );
    }
    
    // set the client format to 16 bit signed integer (native-endian) data
    // maintain the channel count and sample rate of the original source format
    outputFormat.mSampleRate       = fileFormat.mSampleRate;
    outputFormat.mChannelsPerFrame = fileFormat.mChannelsPerFrame;
    outputFormat.mFormatID         = kAudioFormatLinearPCM;
    outputFormat.mBytesPerPacket   = outputFormat.mChannelsPerFrame * 2;
    outputFormat.mFramesPerPacket  = 1;
    outputFormat.mBytesPerFrame    = outputFormat.mChannelsPerFrame * 2;
    outputFormat.mBitsPerChannel   = 16;
    outputFormat.mFormatFlags      = kAudioFormatFlagsNativeEndian |
                                     kAudioFormatFlagIsPacked      |
                                     kAudioFormatFlagIsSignedInteger;
    
    // set the desired client (output) data format
    error = ExtAudioFileSetProperty
            (
                audioFileRef,
                kExtAudioFileProperty_ClientDataFormat,
                sizeof(outputFormat),
                &outputFormat
            );
    CheckAudioDataError("ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat");

    // get the total frame count
    propertySize = sizeof(fileLengthInFrames);
    error        = ExtAudioFileGetProperty
                   (
                       audioFileRef,
                       kExtAudioFileProperty_FileLengthFrames,
                       &propertySize,
                       &fileLengthInFrames
                   );
    CheckAudioDataError("ExtAudioFileGetProperty kExtAudioFileProperty_FileLengthFrames");

    // read all the data into memory
    UInt32 framesToRead = (UInt32) fileLengthInFrames;
    UInt32 dataSize     = framesToRead * outputFormat.mBytesPerFrame;
    
    *outDataSize        = (ALsizei) dataSize;
    *outDataFormat      = outputFormat.mChannelsPerFrame > 1 ? AL_FORMAT_STEREO16 : AL_FORMAT_MONO16;
    *outSampleRate      = (ALsizei) outputFormat.mSampleRate;

    int index           = AArrayStrMap->GetIndex(fileDataMap, relativeFilePath);
    
    if (index < 0)
    {
        data = malloc(dataSize);
        
        AudioBufferList dataBuffer;
        dataBuffer.mNumberBuffers              = 1;
        dataBuffer.mBuffers[0].mDataByteSize   = dataSize;
        dataBuffer.mBuffers[0].mNumberChannels = outputFormat.mChannelsPerFrame;
        dataBuffer.mBuffers[0].mData           = data;

        // read the data into an AudioBufferList
        error = ExtAudioFileRead(audioFileRef, &framesToRead, &dataBuffer);
        CheckAudioDataError("ExtAudioFileRead");

        AArrayStrMap_InsertAt(fileDataMap, relativeFilePath, -index - 1, data);
    }
    else
    {
        data = AArrayStrMap_GetAt(fileDataMap, index, void*);
    }

    // dispose the ExtAudioFileRef, it is no longer needed
    if (audioFileRef != NULL)
    {
        ExtAudioFileDispose(audioFileRef);
    }
    
    return data;
}


#undef CheckAudioDataError


//----------------------------------------------------------------------------------------------------------------------


static ALCdevice*                device                 = NULL;
static ALCcontext*               context                = NULL;
static alBufferDataStaticProcPtr alBufferDataStaticProc = NULL;


struct AudioPlayer
{
    ALuint      sourceId;
    ALuint      bufferId;
    const char* filePath;
};


static void Update(float deltaSeconds)
{
    for (int i = destroyList->size - 1; i > -1; --i)
    {
        AudioPlayer* player = AArrayList_Get(destroyList, i, AudioPlayer*);
        
        ALint state;
        alGetSourcei(player->sourceId, AL_SOURCE_STATE, &state);
        
        if (state == AL_STOPPED)
        {
            alDeleteSources(1, &player->sourceId);
            alDeleteBuffers(1, &player->bufferId);

            player->sourceId = 0;
            player->bufferId = 0;
            player->filePath = NULL;

            AArrayList->Remove(destroyList, i);
            AArrayList_Add(cacheList, player);
        }
    }
}


static void SetLoopPause()
{
    for (int i = 0; i < loopList->size; ++i)
    {
        AAudio->Pause(AArrayList_Get(loopList, i, AudioPlayer*));
    }
}


static void SetLoopResume()
{
    for (int i = 0; i < loopList->size; ++i)
    {
        AAudio->Play(AArrayList_Get(loopList, i, AudioPlayer*));
    }
}


static void Init()
{
    // get static buffer data API
    alBufferDataStaticProc = alcGetProcAddress(NULL, "alBufferDataStatic");
    
    // create a new OpenAL Device
    // pass NULL to specify the system’s default output device
    device = alcOpenDevice(NULL);
    
    if (device != NULL)
    {
        // create a new OpenAL Context
        // the new context will render to the OpenAL Device just created
        context = alcCreateContext(device, 0);
        
        if (context != NULL)
        {
            // make the new context the Current OpenAL Context
            alcMakeContextCurrent(context);
        }
    }
    else
    {
        ALog_E("AAudio Init failed, OpenAL cannot open device");
    }
    
    // clear any errors
    ALenum error;
    CheckAudioError("Init", "");
}


static inline void InitPlayer(const char* relativeFilePath, AudioPlayer* player)
{
    ALenum  error;
    ALsizei size;
    ALenum  format;
    ALsizei freq;
    void*   data = GetAudioData(relativeFilePath, &size, &format, &freq);
    
    alGenBuffers(1, &player->bufferId);
    CheckAudioError("InitPlayer generate buffer", relativeFilePath);
    
    // use the static buffer data API
    // the data will not copy in buffer so cannot free data until buffer deleted
    alBufferDataStaticProc(player->bufferId, format, data, size, freq);
    CheckAudioError("InitPlayer attach audio data to buffer", relativeFilePath);

    alGenSources(1, &player->sourceId);
    CheckAudioError("InitPlayer generate source", relativeFilePath);

    // turn Looping off
    alSourcei(player->sourceId,  AL_LOOPING, AL_FALSE);
    
    // set Source Position
    alSourcefv(player->sourceId, AL_POSITION, (const ALfloat[3]) {0.0f, 0.0f, 0.0f});
    
    // set source reference distance
    alSourcef(player->sourceId,  AL_REFERENCE_DISTANCE, 0.0f);
    
    // attach OpenAL buffer to OpenAL Source
    alSourcei(player->sourceId,  AL_BUFFER, player->bufferId);
    CheckAudioError("InitPlayer attach buffer to source", relativeFilePath);

    // set player name
    player->filePath = AArrayStrSet->Get(filePathSet, relativeFilePath);
}


static void SetLoop(AudioPlayer* player, bool isLoop)
{
    ALint isLoopEnabled;
    alGetSourcei(player->sourceId, AL_LOOPING, &isLoopEnabled);
    
    if (isLoopEnabled == isLoop)
    {
        return;
    }
    
    alSourcei(player->sourceId, AL_LOOPING, (ALint) isLoop);
    
    ArrayList* addList;
    ArrayList* removeList;
    
    if (isLoop)
    {
        addList    = loopList;
        removeList = destroyList;
    }
    else
    {
        addList    = destroyList;
        removeList = loopList;
    }
    
    for (int i = 0; i < removeList->size; ++i)
    {
        if (player == AArrayList_Get(removeList, i, AudioPlayer*))
        {
            AArrayList->RemoveByLast(removeList, i);
            break;
        }
    }
    
    AArrayList_Add(addList, player);
}


static void SetVolume(AudioPlayer* player, float volume)
{
    ALog_A
    (
        volume >= 0.0f && volume <= 1.0f,
        "AAudio SetVolume volume %f not in [0.0, 1.0], audio file path = %s",
        volume,
        player->filePath
    );

    alSourcef(player->sourceId, AL_GAIN, volume);
    
    ALenum error;
    CheckAudioError("SetVolume", player->filePath);
}


static void Play(AudioPlayer* player)
{
    alSourcePlay(player->sourceId);
    ALenum error;
    CheckAudioError("Play", player->filePath);
}


static void Pause(AudioPlayer* player)
{
    alSourcePause(player->sourceId);
    ALenum error;
    CheckAudioError("Pause", player->filePath);
}


static void Stop(AudioPlayer* player)
{
    alSourceStop(player->sourceId);
    ALenum error;
    CheckAudioError("Stop", player->filePath);
    SetLoop(player, false);
}

static bool IsPlaying(AudioPlayer* player)
{
    ALint state;
    alGetSourcei(player->sourceId, AL_SOURCE_STATE, &state);
    return state == AL_PLAYING;
}


static AudioPlayer* GetPlayer(const char* relativeFilePath)
{
    AudioPlayer* player = AArrayList_Pop(cacheList, AudioPlayer*);
    
    if (player == NULL)
    {
        player = malloc(sizeof(AudioPlayer));
    }
    
    InitPlayer(relativeFilePath, player);
    AArrayList_Add(destroyList, player);
    
    return player;
}


#undef CheckAudioError


static void Release()
{
    // release context
    alcDestroyContext(context);
    // close device
    alcCloseDevice(device);

    AArrayStrMap->Release(fileDataMap);
    AArrayList  ->Release(cacheList);
    AArrayList  ->Release(destroyList);
    AArrayList  ->Release(loopList);
    AArrayStrSet->Release(filePathSet);
}


struct AAudio AAudio[1] =
{
    Init,
    Release,
    Update,
    SetLoopPause,
    SetLoopResume,
    GetPlayer,

    SetVolume,
    SetLoop,

    Play,
    Pause,
    Stop,
    IsPlaying,
};


#endif
