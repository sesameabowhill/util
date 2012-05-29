package com.sesamecom.android;

import android.app.Activity;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.*;
import com.sesamecom.android.model.UploadListView;
import com.sesamecom.android.sesameresponse.ErrorResponse;
import com.sesamecom.android.sesameresponse.NeedPasswordResponse;
import com.sesamecom.android.sesameresponse.SesameApiResponse;
import com.sesamecom.android.sesameresponse.UploadQueueResponse;


public class Application extends Activity implements SesameApiListener {

    public static final String UPLOAD_QUEUE_URL = "https://admin.sesamecommunications.com/support-tools/sesame/clients-count.cgi?action=upload_queue_6";
    private SimpleAdapter uploadListAdapter;
    private UploadListView uploadListView;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);

        ListView uploadList = (ListView) findViewById(R.id.upload_list_view);
        uploadListView = new UploadListView();
        uploadListAdapter = new SimpleAdapter(this, uploadListView.getUploadView(), R.layout.upload_list_item,
                new String[] {UploadListView.USERNAME, UploadListView.UPLOAD_START_DATE, UploadListView.COUNT,
                        UploadListView.MESSAGE, UploadListView.PRIORITY, UploadListView.UPLOAD_STEP_DATE},
                new int[] {R.id.item_username, R.id.item_upload_date, R.id.item_count,
                        R.id.item_message, R.id.item_priority, R.id.item_step_date});
        uploadList.setAdapter(uploadListAdapter);

        Button refreshButton = (Button) findViewById(R.id.button_refresh);
        refreshButton.setOnClickListener(new View.OnClickListener() {
            public void onClick(View view) {
                refreshUploadList();
            }
        });
        refreshUploadList();
    }

    private AsyncTask<String, Void, SesameApiResponse> refreshUploadList() {
        findViewById(R.id.button_refresh).setEnabled(false);
        findViewById(R.id.progress_loading).setVisibility(View.VISIBLE);
        Settings settings = Settings.getFromContextWrapper(this);
        return new RefreshUploadList(Application.this).execute(UPLOAD_QUEUE_URL,
                settings.getUsername(), settings.getPassword());
    }

    @Override
    public void onSesameApiResponse(SesameApiResponse response) {
        findViewById(R.id.button_refresh).setEnabled(true);
        findViewById(R.id.progress_loading).setVisibility(View.INVISIBLE);
        if (response instanceof UploadQueueResponse) {
            UploadQueueResponse uploadQueue = (UploadQueueResponse) response;
            uploadListView.update(uploadQueue.getUploads());
            uploadListAdapter.notifyDataSetChanged();
            updateTotalNumbers();
        } else if (response instanceof NeedPasswordResponse) {
            Toast.makeText(getApplicationContext(), "Username or Password is incorrect.",  Toast.LENGTH_LONG).show();
        } else if (response instanceof ErrorResponse) {
            Toast.makeText(getApplicationContext(), ((ErrorResponse) response).getMessage(),  Toast.LENGTH_LONG).show();
        }
    }

    private void updateTotalNumbers() {
        StringBuilder statusText = new StringBuilder();
        statusText.append("In progress: ").append(uploadListView.getInProgress()).append("\n");
        if (uploadListView.getInQueue() > 0) {
            statusText.append("In queue: ").append(uploadListView.getInQueue()).append("\n");
        }
        ((TextView)findViewById(R.id.text_total_upload)).setText(statusText);
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
