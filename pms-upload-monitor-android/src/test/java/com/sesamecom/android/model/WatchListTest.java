package com.sesamecom.android.model;

import junit.framework.TestCase;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.BlockJUnit4ClassRunner;
import org.junit.runners.JUnit4;

import java.util.Collections;
import java.util.LinkedList;
import java.util.List;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

/**
 * Created by Ivan
 * If you see "!!! JUnit version 3.8 or later expected:" then move junit dependency before android
 */
public class WatchListTest {
    @Test
    public void testStartProcess() throws Exception {
        WatchList watchList = new WatchList();
        UploadEventListener listener = mock(UploadEventListener.class);
        watchList.addListener(listener);
        watchList.startWatchingClient("client1");
        watchList.queueUpdated(makeList("client1"), makeList());
        verify(listener).processStarted("client1");
    }

    private Iterable<String> makeList(String... clients) {
        List<String> list = new LinkedList<String>();
        Collections.addAll(list, clients);
        return list;
    }
}
