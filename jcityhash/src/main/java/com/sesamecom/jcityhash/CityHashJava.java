package com.sesamecom.jcityhash;

/**
 * The results of a brief attempt to port CityHash to Java.
 */
public class CityHashJava {
/*
    public String hash64(String s) {
        int len = s.length();
        if (len <= 32) {
            if (len <= 16) {
                return HashLen0to16(s);
            } else {
                return HashLen17to32(s);
            }
        } else if (len <= 64) {
            return HashLen33to64(s);
        } else {
            throw new UnsupportedOperationException();
        }
    }

    private String HashLen0to16(String s) {
        int len = s.length();

        if (len > 8) {
            long a = Fetch64(s);
            long b = Fetch64(s);
        }
    }

    private long Fetch64(String s) {
        
    }

    private String HashLen17to32(String s) {
    }

    private String HashLen33to64(String s) {
    }
    */
}
