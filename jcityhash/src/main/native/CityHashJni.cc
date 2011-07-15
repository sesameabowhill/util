#include "jni.h"
#include "com_sesamecom_jcityhash_CityHash.h"
#include "city.h"

// the maximum value for a uint64 is 18446744073709551615, which has 20 digits.
#define MAX_UINT64_DIGITS 20

// a JNI wrapper around CityHash64 that takes a jstring message, and returns a uint64 hash code in a jstring.
extern "C"
JNIEXPORT jstring JNICALL Java_com_sesamecom_jcityhash_CityHash_hash64Native
  (JNIEnv* env, jclass clazz, jstring javaString)
{
    const char* message = env->GetStringUTFChars(javaString, 0);
    jsize length = env->GetStringLength(javaString);

    uint64 hashCode = CityHash64(message, (int) length);

    // java doesn't have a type equivalent to uint64, so convert the hash code to a string.
    char codeString [MAX_UINT64_DIGITS + 1];
    sprintf(codeString, "%llu", hashCode);

    // this releases the heap memory allocated for "message"
    env->ReleaseStringUTFChars(javaString, message);

    // codeString, length, and hashCode were allocated on the stack and so don't need freeing.

    return env->NewStringUTF(codeString);
}
