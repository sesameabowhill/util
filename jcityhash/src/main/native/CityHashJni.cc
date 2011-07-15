#include "jni.h"
#include "com_sesamecom_jcityhash_CityHash.h"
#include "city.h"

extern "C"
JNIEXPORT jstring JNICALL Java_com_sesamecom_util_CityHash_hash64
  (JNIEnv* env, jclass clazz, jstring message)
{
    return message;
}
