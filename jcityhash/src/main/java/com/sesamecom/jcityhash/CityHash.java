package com.sesamecom.jcityhash;

/**
 * A JNI wrapper around the excellent CityHash library.  It's an extremely small library, but very dense, and uses a lot
 * of datatypes that don't exist in Java, making it potentially difficult to port.
 */
public class CityHash {
    static {
        Native.loadNativeLibrary();
    }

    /**
     * Returns unsigned 64bit integer hash code as a string, due to lack of unsigned types in Java.
     */
    public static String hash64(String message) {
        if (message == null) return null;
        return hash64Native(message).trim();
    }

    private static native String hash64Native(String message);
}
