package com.sesamecom.android;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.view.*;
import android.widget.*;
import com.sesamecom.android.model.UploadListView;
import com.sesamecom.android.sesameresponse.ErrorResponse;
import com.sesamecom.android.sesameresponse.NeedPasswordResponse;
import com.sesamecom.android.sesameresponse.SesameApiResponse;
import com.sesamecom.android.sesameresponse.UploadQueueResponse;


public class Application extends Activity implements SesameApiListener {

    public static final String UPLOAD_QUEUE_URL = "https://admin.sesamecommunications.com/support-tools/sesame/clients-count.cgi?action=upload_queue_6";
    private UploadListAdapter uploadListAdapter;
    private UploadListView uploadListView;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);

        ListView uploadList = (ListView) findViewById(R.id.upload_list_view);
        uploadListView = new UploadListView();
        uploadListAdapter = new UploadListAdapter(uploadListView,
                (LayoutInflater)getSystemService(Context.LAYOUT_INFLATER_SERVICE));
        uploadList.setAdapter(uploadListAdapter);

//        Button refreshButton = (Button) findViewById(R.id.button_refresh);
//        refreshButton.setOnClickListener(new View.OnClickListener() {
//            public void onClick(View view) {
//                refreshUploadList();
//            }
//        });
        refreshUploadList();
    }

    private AsyncTask<String, Void, SesameApiResponse> refreshUploadList() {
//        findViewById(R.id.button_refresh).setEnabled(false);
        findViewById(R.id.progress_loading).setVisibility(View.VISIBLE);
        Settings settings = Settings.getFromContextWrapper(this);
        return new RefreshUploadList(Application.this).execute(UPLOAD_QUEUE_URL,
                settings.getUsername(), settings.getPassword());
    }

    @Override
    public void onSesameApiResponse(SesameApiResponse response) {
//        findViewById(R.id.button_refresh).setEnabled(true);
        findViewById(R.id.progress_loading).setVisibility(View.INVISIBLE);
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
