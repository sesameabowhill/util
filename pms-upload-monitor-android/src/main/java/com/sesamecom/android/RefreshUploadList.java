package com.sesamecom.android;

import android.net.http.AndroidHttpClient;
import android.os.AsyncTask;
import android.util.Base64;
import android.util.Log;
import com.google.gson.FieldNamingPolicy;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonParseException;
import com.google.gson.stream.JsonReader;
import com.sesamecom.android.model.MemberUploadInfo;
import com.sesamecom.android.sesameresponse.ErrorResponse;
import com.sesamecom.android.sesameresponse.NeedPasswordResponse;
import com.sesamecom.android.sesameresponse.SesameApiResponse;
import com.sesamecom.android.sesameresponse.UploadQueueResponse;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.HttpStatus;
import org.apache.http.auth.Credentials;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.methods.HttpGet;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.text.DateFormat;
import java.util.ArrayList;
import java.util.List;

/**
 * Created by Ivan
 */
public class RefreshUploadList extends AsyncTask<String, Void, SesameApiResponse> {

    public static final Gson GSON = new GsonBuilder()
            .setFieldNamingPolicy(FieldNamingPolicy.LOWER_CASE_WITH_UNDERSCORES)
            .setDateFormat("yyyy-MM-dd HH:mm:ss Z")
            .create();

    private SesameApiListener apiListener;

    public RefreshUploadList(Application apiListener) {
        this.apiListener = apiListener;
    }


    @Override
    protected SesameApiResponse doInBackground(String... settings) {
        final AndroidHttpClient client = AndroidHttpClient.newInstance("Android");
        String url = settings[0];
        String username = settings[1];
        String password = settings[2];
        final HttpGet request = new HttpGet(url);
        byte[] authBytes = (username + ":" + password).getBytes();
        request.addHeader("Authorization", "Basic " + Base64.encodeToString(authBytes, Base64.DEFAULT));
        try {
            HttpResponse response = client.execute(request);
            if (response.getStatusLine().getStatusCode() == HttpStatus.SC_UNAUTHORIZED) {
                return new NeedPasswordResponse();
            } else if (response.getStatusLine().getStatusCode() == HttpStatus.SC_OK) {
                HttpEntity entity = response.getEntity();
                if (entity != null) {
                    return new UploadQueueResponse(parseEntityContent(entity));
                } else {
                    return returnError("Can't get URL [" + url + "]: empty content");
                }
            } else {
                return returnError("Can't get URL [" + url + "]: unexpected http response " +
                        response.getStatusLine());
            }
        } catch (IOException e) {
            return returnError("Can't get URL [" + url + "]: " + e.getMessage());
        } catch (JsonParseException e) {
            return returnError("Can't get URL [" + url + "]: " + e.getMessage());
        } finally {
            if (client != null) {
                client.close();
            }
        }
    }

    private SesameApiResponse returnError(String error) {
        Log.w("RefreshUploadList", error);
        return new ErrorResponse(error);
    }

    private List<MemberUploadInfo> parseEntityContent(HttpEntity entity) throws IOException {
        InputStream contentStream = null;
        JsonReader jsonReader = null;
        try {
            contentStream = entity.getContent();
            jsonReader = new JsonReader(new InputStreamReader(contentStream));
            jsonReader.beginArray();
            List<MemberUploadInfo> uploads = new ArrayList<MemberUploadInfo>();
            while (jsonReader.hasNext()) {
                MemberUploadInfo uploadInfo = GSON.fromJson(jsonReader, MemberUploadInfo.class);
                uploads.add(uploadInfo);
            }
            jsonReader.endArray();
            return uploads;
        } finally {
            if (contentStream != null) {
                contentStream.close();
            }
            if (jsonReader != null) {
                jsonReader.close();
            }
            entity.consumeContent();
        }
    }

    @Override
    protected void onPostExecute(SesameApiResponse response) {
        apiListener.onSesameApiResponse(response);
    }
}
