package com.sesamecom.jcityhash;

import com.sesamecom.jcityhash.NarSystem;

/**
 * A JNI wrapper around the excellent CityHash.
 */
public class CityHash {
    static {
        NarSystem.loadLibrary();
    }

    /**
     * Returns unsigned 64bit integer hash code as a string, due to lack of unsigned types in Java.
     */
    public static native String hash64(String message);
}
