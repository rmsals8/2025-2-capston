package com.trip_helper.app;

import io.flutter.embedding.android.FlutterActivity;
import android.content.pm.PackageManager;
import android.content.pm.PackageInfo;
import android.content.pm.Signature;
import android.util.Base64;
import android.util.Log;
import android.os.Bundle;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

public class MainActivity extends FlutterActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getKeyHash();
    }

    private void getKeyHash() {
        try {
            PackageInfo info = getPackageManager().getPackageInfo(
                    getPackageName(),
                    PackageManager.GET_SIGNATURES
            );

            for (Signature signature : info.signatures) {
                MessageDigest md = MessageDigest.getInstance("SHA");
                md.update(signature.toByteArray());
                String keyHash = Base64.encodeToString(md.digest(), Base64.DEFAULT);

                Log.d("KAKAO_KEY_HASH", "=========================");
                Log.d("KAKAO_KEY_HASH", "Package: " + getPackageName());
                Log.d("KAKAO_KEY_HASH", "KeyHash: " + keyHash);
                Log.d("KAKAO_KEY_HASH", "=========================");

                // 콘솔에도 출력
                System.out.println("=========================");
                System.out.println("Package: " + getPackageName());
                System.out.println("KeyHash: " + keyHash);
                System.out.println("=========================");
            }
        } catch (PackageManager.NameNotFoundException e) {
            Log.e("KAKAO_KEY_HASH", "패키지를 찾을 수 없습니다", e);
        } catch (NoSuchAlgorithmException e) {
            Log.e("KAKAO_KEY_HASH", "SHA 알고리즘을 찾을 수 없습니다", e);
        }
    }
}