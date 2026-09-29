// SILIMU — version légère : l'application affiche le site SILIMU
// dans une fenêtre plein écran. Aucun moteur Flutter embarqué,
// l'APK pèse environ 2 Mo au lieu de 16 Mo.

package cd.silimu.app;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends Activity {

    private static final String PREFS = "silimu";
    private static final String CLE_URL = "url";

    // Adresse pré-remplie au premier lancement : le site SILIMU en accès
    // public (fonctionne en Wi-Fi comme en data mobile). Elle reste
    // modifiable avec le bouton « Adresse ».
    private static final String URL_DEFAUT = "https://admit-closely-peoples-skiing.trycloudflare.com";

    private WebView web;
    private LinearLayout racine;
    private LinearLayout barre;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle etat) {
        super.onCreate(etat);
        getWindow().setStatusBarColor(Color.parseColor("#07303F"));
        racine = new LinearLayout(this);
        racine.setOrientation(LinearLayout.VERTICAL);
        racine.setBackgroundColor(Color.WHITE);
        racine.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        web = new WebView(this);
        WebSettings reglages = web.getSettings();
        reglages.setJavaScriptEnabled(true);
        reglages.setDomStorageEnabled(true);
        reglages.setDatabaseEnabled(true);
        reglages.setLoadWithOverviewMode(true);
        reglages.setUseWideViewPort(true);
        reglages.setBuiltInZoomControls(true);
        reglages.setDisplayZoomControls(false);
        reglages.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        reglages.setCacheMode(WebSettings.LOAD_DEFAULT);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            reglages.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        }
        WebView.setWebContentsDebuggingEnabled(false);
        web.setWebViewClient(new WebViewClient() {
            @Override
            public void onReceivedError(WebView vue, WebResourceRequest requete, WebResourceError erreur) {
                if (requete.isForMainFrame()) {
                    vue.loadUrl("javascript:document.getElementById('erreur').style.display='block';");
                }
            }
        });

        barre = new LinearLayout(this);
        barre.setOrientation(LinearLayout.HORIZONTAL);
        barre.setGravity(Gravity.CENTER_VERTICAL);
        barre.setPadding(24, 12, 24, 12);
        barre.setBackgroundColor(Color.parseColor("#07303F"));

        TextView titre = new TextView(this);
        titre.setText("SILIMU");
        titre.setTextColor(Color.WHITE);
        titre.setTextSize(18);
        titre.setPadding(0, 0, 0, 0);
        LinearLayout.LayoutParams pTitre = new LinearLayout.LayoutParams(0,
                ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        barre.addView(titre, pTitre);

        Button changer = new Button(this);
        changer.setText("Adresse");
        changer.setTextSize(12);
        changer.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                demanderAdresse();
            }
        });
        barre.addView(changer);

        racine.addView(barre, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        racine.addView(web, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        setContentView(racine);

        chargerUrl();
    }

    private SharedPreferences prefs() {
        return getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private void chargerUrl() {
        String url = prefs().getString(CLE_URL, "");
        if (url == null || url.trim().isEmpty()) {
            demanderAdresse();
            return;
        }
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            url = "http://" + url;
            prefs().edit().putString(CLE_URL, url).apply();
        }
        if (!url.endsWith("/")) {
            url = url + "/";
        }
        web.loadUrl(url);
    }

    private void demanderAdresse() {
        final LinearLayout boite = new LinearLayout(this);
        boite.setOrientation(LinearLayout.VERTICAL);
        boite.setPadding(48, 64, 48, 48);
        boite.setBackgroundColor(Color.WHITE);

        TextView titre = new TextView(this);
        titre.setText("Adresse du serveur SILIMU");
        titre.setTextColor(Color.parseColor("#07303F"));
        titre.setTextSize(20);
        titre.setPadding(0, 0, 0, 24);
        boite.addView(titre);

        final EditText saisie = new EditText(this);
        saisie.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        saisie.setHint("ex. http://192.168.1.10:8000");
        saisie.setText(prefs().getString(CLE_URL, URL_DEFAUT));
        boite.addView(saisie);

        final TextView erreur = new TextView(this);
        erreur.setText("Site injoignable. Vérifie le Wi-Fi et l'adresse.");
        erreur.setTextColor(Color.parseColor("#F47533"));
        erreur.setVisibility(View.GONE);
        erreur.setPadding(0, 16, 0, 0);
        boite.addView(erreur);

        Button valider = new Button(this);
        valider.setText("Se connecter");
        valider.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                String url = saisie.getText().toString().trim();
                if (url.isEmpty()) {
                    erreur.setVisibility(View.VISIBLE);
                    return;
                }
                if (!url.startsWith("http://") && !url.startsWith("https://")) {
                    url = "http://" + url;
                }
                prefs().edit().putString(CLE_URL, url).apply();
                boite.removeAllViews();
                racine.addView(barre, 0);
                racine.addView(web, 1);
                web.loadUrl(url);
                Toast.makeText(MainActivity.this, "Connexion…", Toast.LENGTH_SHORT).show();
            }
        });
        boite.addView(valider);

        racine.removeAllViews();
        racine.addView(boite);
    }

    @Override
    public void onBackPressed() {
        if (web != null && web.canGoBack()) {
            web.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
