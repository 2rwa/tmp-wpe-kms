#include <glib.h>
#include <glib-object.h>
#include <jsc/jsc.h>
#include <wpe/webkit.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    GMainLoop *loop;
    gboolean test_mode;
    gboolean evaluation_started;
    int result;
} App;

static gboolean on_timeout(gpointer user_data)
{
    App *app = user_data;
    g_printerr("FAIL: timed out waiting for WebKit navigation/JavaScript\n");
    app->result = 124;
    g_main_loop_quit(app->loop);
    return G_SOURCE_REMOVE;
}

static void on_javascript_finished(GObject *source, GAsyncResult *async_result, gpointer user_data)
{
    App *app = user_data;
    g_autoptr(GError) error = NULL;
    JSCValue *value = webkit_web_view_evaluate_javascript_finish(
        WEBKIT_WEB_VIEW(source), async_result, &error);
    if (!value) {
        g_printerr("FAIL: JavaScript evaluation: %s\n",
                   error ? error->message : "unknown error");
        app->result = 2;
    } else {
        g_autofree gchar *result = jsc_value_to_string(value);
        g_print("WebKit DOM regression: %s\n", result);
        app->result = g_str_has_prefix(result, "PASS: DOM and interaction redraw [") ? 0 : 3;
        g_object_unref(value);
    }
    g_main_loop_quit(app->loop);
}

static void on_load_changed(WebKitWebView *view, WebKitLoadEvent event, gpointer user_data)
{
    App *app = user_data;
    if (event != WEBKIT_LOAD_FINISHED || !app->test_mode || app->evaluation_started)
        return;
    app->evaluation_started = TRUE;
    const char *script =
        "(() => {"
        "const mode=document.getElementById('mode-button');"
        "const label=document.getElementById('mode-label');"
        "const sel=document.getElementById('platform-selector');"
        "const cmd=document.getElementById('command');"
        "if(!mode||!label||!sel||!cmd) return 'FAIL: controls missing at '+location.href+' body='+(document.body?.innerText||'no body').slice(0,160);"
        "if(!cmd.textContent.includes('WPE_PLATFORM=drm')) return 'FAIL: initial DRM';"
        "mode.click();"
        "if(!label.textContent.includes('2GB')) return 'FAIL: mode change';"
        "sel.value='headless';"
        "sel.dispatchEvent(new Event('change',{bubbles:true}));"
        "if(!cmd.textContent.includes('WPE_PLATFORM=headless')) return 'FAIL: command redraw';"
        "const canvas=document.createElement('canvas');"
        "let gl2=false,gl1=false;"
        "try{gl2=!!canvas.getContext('webgl2');gl1=gl2||!!canvas.getContext('webgl');}catch(e){}"
        "const rtc=typeof RTCPeerConnection==='function';"
        "return 'PASS: DOM and interaction redraw [WebGL1='+gl1+' WebGL2='+gl2+' RTC='+rtc+']';"
        "})()";
    webkit_web_view_evaluate_javascript(view, script, -1, NULL, NULL, NULL,
                                        on_javascript_finished, app);
}

static gboolean on_load_failed(WebKitWebView *view, WebKitLoadEvent event,
                               gchar *uri, GError *error, gpointer user_data)
{
    (void)view;
    (void)event;
    App *app = user_data;
    g_printerr("FAIL: navigation to %s: %s\n", uri, error->message);
    app->result = 4;
    g_main_loop_quit(app->loop);
    return FALSE;
}

int main(int argc, char **argv)
{
    gboolean test_mode = argc > 1 && strcmp(argv[1], "--test") == 0;
    const char *uri = argc > (test_mode ? 2 : 1) ? argv[test_mode ? 2 : 1]
                                                : "https://wpewebkit.org/";
    g_autoptr(GMainLoop) loop = g_main_loop_new(NULL, FALSE);
    App app = { .loop = loop, .test_mode = test_mode,
                .evaluation_started = FALSE, .result = test_mode ? 1 : 0 };
    g_autoptr(WebKitWebView) view =
        WEBKIT_WEB_VIEW(g_object_new(WEBKIT_TYPE_WEB_VIEW, NULL));
    if (!view) {
        g_printerr("FAIL: WebKitWebView creation\n");
        return EXIT_FAILURE;
    }
    // Build-time support needs runtime WebKitSettings for the features.
    WebKitSettings *settings = webkit_web_view_get_settings(view);
    g_object_set(settings,
                 "enable-webgl", TRUE,
                 "enable-webrtc", TRUE,
                 "enable-media-stream", TRUE,
                 NULL);
    g_signal_connect(view, "load-changed", G_CALLBACK(on_load_changed), &app);
    g_signal_connect(view, "load-failed", G_CALLBACK(on_load_failed), &app);
    if (test_mode)
        g_timeout_add_seconds(60, on_timeout, &app);
    g_print("WPE WebKit %u.%u.%u, WPE_PLATFORM=%s, URI=%s\n",
            webkit_get_major_version(), webkit_get_minor_version(),
            webkit_get_micro_version(),
            g_getenv("WPE_PLATFORM") ? g_getenv("WPE_PLATFORM") : "(auto)", uri);
    webkit_web_view_load_uri(view, uri);
    g_main_loop_run(loop);
    return app.result;
}
