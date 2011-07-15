package com.sesamecom.jcityhash;

import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

public class CityHashTest {
    @Test
    public void hashesHello() {
        assertEquals("2578220239953316063", CityHash.hash64("hello"));
    }

    @Test
    public void hashesToNullOnNull() {
        assertNull(CityHash.hash64(null));
    }
}
