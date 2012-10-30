package com.sesamecom.android.helper;

import android.os.Handler;

/**
 * Created by Ivan
 */
public class TaskRunner implements Runnable {
    private final Handler handler;
    private final Runnable task;
    private final Settings settings;
    private final Settings.Key intervalKey;

    public TaskRunner(Handler handler, Settings settings, Runnable task, Settings.Key intervalKey) {
        this.handler = handler;
        this.task = task;
        this.settings = settings;
        this.intervalKey = intervalKey;
    }

    public void scheduleNextRun() {
        stop();
        int refresh = settings.getIntervalValue(intervalKey);
        if (refresh > 0) {
            handler.postDelayed(this, refresh * 1000);
        }
    }

    public void stop() {
        handler.removeCallbacks(this);
    }

    @Override
    public void run() {
        task.run();
        scheduleNextRun();
    }

}
