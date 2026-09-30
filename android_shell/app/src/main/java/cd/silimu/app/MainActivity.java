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

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

public class MainActivity extends Activity {

    private static final String PREFS = "silimu";
    private static final String CLE_URL = "url";

    // Adresse de tout secours, seulement si la découverte automatique échoue
    // (par exemple aucune connexion au moment du premier lancement).
    private static final String URL_DEFAUT = "https://davidbafulwa.github.io";

    // Fichier texte publié avec l'adresse du site SILIMU. Il ne change
    // jamais : l'application y lit l'adresse à jour, ce qui évite toute
    // saisie d'adresse IP ou de port.
    private static final String ADRESSE_OFFICIELLE =
            "https://davidbafulwa.github.io/silimu-app/adresse-serveur.txt";

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
                // Retrouve l'adresse officielle avant d'ouvrir la saisie
                chercherAdresse(new Runnable() {
                    @Override
                    public void run() {
                        demanderAdresse();
                    }
                });
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

    /**
     * Va chercher l'adresse officielle du site SILIMU.
     *
     * L'adresse publique change quand la connexion de l'ordinateur qui
     * héberge le site est rétablie : au lieu de demander une adresse IP et un
     * port à l'utilisateur, l'application lit cette adresse toute seule. Il
     * n'y a donc plus rien à saisir, ni à ré saisir après un changement.
     */
    private void chercherAdresse(final Runnable apres) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                String trouvee = "";
                HttpURLConnection connexion = null;
                try {
                    URL source = new URL(ADRESSE_OFFICIELLE + "?t=" + System.currentTimeMillis());
                    connexion = (HttpURLConnection) source.openConnection();
                    connexion.setConnectTimeout(8000);
                    connexion.setReadTimeout(8000);
                    connexion.setRequestProperty("Cache-Control", "no-cache");
                    if (connexion.getResponseCode() == 200) {
                        BufferedReader lecteur = new BufferedReader(
                                new InputStreamReader(connexion.getInputStream(), "UTF-8"));
                        StringBuilder texte = new StringBuilder();
                        String ligne = lecteur.readLine();
                        while (ligne != null) {
                            texte.append(ligne);
                            ligne = lecteur.readLine();
                        }
                        String adresse = texte.toString().trim();
                        if (adresse.startsWith("http")) {
                            trouvee = adresse;
                            prefs().edit().putString(CLE_URL, trouvee).apply();
                        }
                    }
                } catch (Exception e) {
                    // Pas de réseau ou adresse indisponible : on garde celle déjà connue
                } finally {
                    if (connexion != null) {
                        connexion.disconnect();
                    }
                }
                final boolean ok = !trouvee.isEmpty();
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        if (ok) {
                            Toast.makeText(MainActivity.this,
                                    "Adresse du serveur mise à jour", Toast.LENGTH_SHORT).show();
                        }
                        apres.run();
                    }
                });
            }
        }).start();
    }

    private void chargerUrl() {
        chercherAdresse(new Runnable() {
            @Override
            public void run() {
                afficherSite();
            }
        });
    }

    private void afficherSite() {
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
        saisie.setHint("trouvée automatiquement");
        saisie.setText(prefs().getString(CLE_URL, URL_DEFAUT));
        boite.addView(saisie);

        TextView aide = new TextView(this);
        aide.setText("L'adresse est normalement trouvée seule. Ce champ "
                + "ne sert que si tu veux forcer une autre adresse.");
        aide.setTextColor(Color.parseColor("#6B7A82"));
        aide.setTextSize(12);
        aide.setPadding(0, 8, 0, 8);
        boite.addView(aide);

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
