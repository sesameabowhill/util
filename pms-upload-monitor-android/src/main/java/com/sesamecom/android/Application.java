package com.sesamecom.android;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Handler;
import android.view.*;
import android.widget.*;
import com.sesamecom.android.helper.Settings;
import com.sesamecom.android.helper.TaskRunner;
import com.sesamecom.android.model.UploadListView;
import com.sesamecom.android.response.ErrorResponse;
import com.sesamecom.android.response.NeedPasswordResponse;
import com.sesamecom.android.response.SesameApiResponse;
import com.sesamecom.android.response.UploadQueueResponse;


public class Application extends Activity implements SesameApiListener {

    public static final String UPLOAD_QUEUE_URL = "https://admin.sesamecommunications.com/support-tools/sesame/clients-count.cgi?action=upload_queue_6";
    private UploadListAdapter uploadListAdapter;
    private UploadListView uploadListView;
    private Settings settings;
    private TaskRunner redrawTask;
    private TaskRunner uploadListReloadTask;

    public Application() {
        uploadListView = new UploadListView();
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);

        settings = Settings.getFromContextWrapper(this);

        setContentView(R.layout.main);

        ListView uploadList = (ListView) findViewById(R.id.upload_list_view);
        LayoutInflater inflater = (LayoutInflater) getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        uploadListAdapter = new UploadListAdapter(uploadListView, inflater);
        uploadList.setAdapter(uploadListAdapter);
        uploadList.setKeepScreenOn(true);

        initSchedulingTasks();

        refreshUploadList();
    }

    private void initSchedulingTasks() {
        Handler handler = new Handler();

        redrawTask = new TaskRunner(handler, settings, new Runnable() {
            @Override
            public void run() {
                uploadListAdapter.notifyDataSetChanged();
            }
        }, Settings.Key.RedrawInterval);

        uploadListReloadTask = new TaskRunner(handler, settings, new Runnable() {
            @Override
            public void run() {
                refreshUploadList();
            }
        }, Settings.Key.UploadListReloadInterval);

        redrawTask.scheduleNextRun();
        uploadListReloadTask.scheduleNextRun();

        settings.registerOnSharedPreferenceChangeListener(new SharedPreferences.OnSharedPreferenceChangeListener() {
            @Override
            public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String s) {
                redrawTask.scheduleNextRun();
                uploadListReloadTask.scheduleNextRun();
            }
        });
    }

    @Override
    protected void onDestroy() {
        redrawTask.stop();
        uploadListReloadTask.stop();
        super.onDestroy();
    }

    private AsyncTask<String, Void, SesameApiResponse> refreshUploadList() {
        setProgressBarIndeterminateVisibility(true);
        uploadListReloadTask.stop();
        return new RefreshUploadList(Application.this).execute(UPLOAD_QUEUE_URL,
                settings.getUsername(), settings.getPassword());
    }

    @Override
    public void onSesameApiResponse(SesameApiResponse response) {
        setProgressBarIndeterminateVisibility(false);
        uploadListReloadTask.scheduleNextRun();
        if (response instanceof UploadQueueResponse) {
            UploadQueueResponse uploadQueue = (UploadQueueResponse) response;
            uploadListView.update(uploadQueue.getUploads());
            uploadListAdapter.notifyDataSetChanged();
        } else if (response instanceof NeedPasswordResponse) {
            Toast.makeText(getApplicationContext(), "Username or Password is incorrect.",  Toast.LENGTH_LONG).show();
        } else if (response instanceof ErrorResponse) {
            Toast.makeText(getApplicationContext(), ((ErrorResponse) response).getMessage(),  Toast.LENGTH_LONG).show();
        }
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater menuInflater = getMenuInflater();
        menuInflater.inflate(R.menu.menu, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.menu_item_refresh:
                refreshUploadList();
                return true;
            case R.id.menu_item_settings:
                startActivity(new Intent(this, Preferences.class));
                return false;
            default:
                return super.onOptionsItemSelected(item);
        }
    }
}
