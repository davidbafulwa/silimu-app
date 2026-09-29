# On conserve l'activité et les méthodes utilisées par le WebView.
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, android.webkit.WebResourceRequest, android.webkit.WebResourceError);
}
