package com.sesamecom.jcityhash;

import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class CityHashTest {
    @Test
    public void smoke() {
        assertEquals(CityHash.hash64("hello"), "hello");
    }
}
