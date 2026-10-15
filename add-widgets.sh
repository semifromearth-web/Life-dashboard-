#!/bin/bash
set -e
J=android/app/src/main/java/com/senn/lifedashboard
RS=android/app/src/main/res
mkdir -p $J $RS/xml $RS/layout

cat > $J/MainActivity.java <<'EOF'
package com.senn.lifedashboard;
import android.os.Bundle;
import com.getcapacitor.BridgeActivity;
public class MainActivity extends BridgeActivity {
  @Override public void onCreate(Bundle b) { registerPlugin(WidgetBridge.class); super.onCreate(b); }
}
EOF

cat > $J/WidgetBridge.java <<'EOF'
package com.senn.lifedashboard;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
@CapacitorPlugin(name = "WidgetBridge")
public class WidgetBridge extends Plugin {
  @PluginMethod
  public void setData(PluginCall call) {
    Context c = getContext();
    c.getSharedPreferences("ld_widget", 0).edit().putString("data", call.getString("json", "{}")).apply();
    AppWidgetManager m = AppWidgetManager.getInstance(c);
    Class<?>[] ks = { HabitsWidget.class, RunsWidget.class };
    for (Class<?> k : ks) {
      int[] ids = m.getAppWidgetIds(new ComponentName(c, k));
      if (ids.length > 0) c.sendBroadcast(new Intent(c, k).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE).putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids));
    }
    call.resolve();
  }
}
EOF

cat > $J/BaseWidget.java <<'EOF'
package com.senn.lifedashboard;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.graphics.*;
import android.widget.RemoteViews;
import org.json.JSONObject;
public abstract class BaseWidget extends AppWidgetProvider {
  abstract String key();
  abstract int color();
  @Override public void onUpdate(Context c, AppWidgetManager m, int[] ids) {
    JSONObject o = null;
    try { o = new JSONObject(c.getSharedPreferences("ld_widget", 0).getString("data", "{}")).optJSONObject(key()); } catch (Exception e) {}
    Bitmap b = o == null ? draw("Life Dashboard", 0, "-", "Open the app", "to load your data", "")
      : draw(o.optString("t"), o.optInt("pct"), o.optString("big"), o.optString("l1"), o.optString("l2"), o.optString("l3"));
    Intent li = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
    PendingIntent pi = PendingIntent.getActivity(c, 0, li, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    for (int id : ids) {
      RemoteViews v = new RemoteViews(c.getPackageName(), R.layout.widget_card);
      v.setImageViewBitmap(R.id.img, b);
      v.setOnClickPendingIntent(R.id.img, pi);
      m.updateAppWidget(id, v);
    }
  }
  Bitmap draw(String t, int pct, String big, String l1, String l2, String l3) {
    Bitmap b = Bitmap.createBitmap(720, 330, Bitmap.Config.ARGB_8888);
    Canvas c = new Canvas(b);
    Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    RectF card = new RectF(4, 4, 716, 326);
    p.setColor(0xFF0D0E12); c.drawRoundRect(card, 48, 48, p);
    p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(3); p.setColor(0xFF1B1D24); c.drawRoundRect(card, 48, 48, p);
    RectF ring = new RectF(65, 60, 275, 270);
    p.setStrokeWidth(22); p.setStrokeCap(Paint.Cap.ROUND);
    p.setColor(0xFF1B1D24); c.drawArc(ring, 0, 360, false, p);
    int q = Math.max(0, Math.min(100, pct));
    if (q > 0) { p.setColor(color()); c.drawArc(ring, -90, 360f * q / 100f, false, p); }
    p.setStyle(Paint.Style.FILL);
    p.setTypeface(Typeface.DEFAULT_BOLD); p.setTextAlign(Paint.Align.CENTER);
    p.setColor(0xFFECEEF4); p.setTextSize(big.length() > 4 ? 44 : 54); c.drawText(big, 170, 186, p);
    p.setTextAlign(Paint.Align.LEFT);
    p.setTypeface(Typeface.DEFAULT); p.setColor(0xFF737888); p.setTextSize(32); c.drawText(t, 330, 86, p);
    p.setTypeface(Typeface.DEFAULT_BOLD); p.setColor(0xFFECEEF4); p.setTextSize(48); c.drawText(l1, 330, 160, p);
    p.setTypeface(Typeface.DEFAULT); p.setColor(0xFF737888); p.setTextSize(32);
    c.drawText(l2, 330, 218, p); c.drawText(l3, 330, 264, p);
    return b;
  }
}
EOF

cat > $J/HabitsWidget.java <<'EOF'
package com.senn.lifedashboard;
public class HabitsWidget extends BaseWidget {
  String key() { return "habits"; }
  int color() { return 0xFF2F8F66; }
}
EOF
cat > $J/RunsWidget.java <<'EOF'
package com.senn.lifedashboard;
public class RunsWidget extends BaseWidget {
  String key() { return "runs"; }
  int color() { return 0xFF3B7EA8; }
}
EOF

cat > $RS/layout/widget_card.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<ImageView xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/img" android:layout_width="match_parent" android:layout_height="match_parent"
    android:scaleType="fitCenter" />
EOF
for n in habits runs; do
cat > $RS/xml/${n}_widget_info.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp" android:minHeight="110dp" android:updatePeriodMillis="1800000"
    android:resizeMode="horizontal|vertical" android:widgetCategory="home_screen"
    android:initialLayout="@layout/widget_card" />
EOF
done

cat > receivers.xml <<'EOF'
<receiver android:name=".HabitsWidget" android:label="Habits" android:exported="false">
  <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
  <meta-data android:name="android.appwidget.provider" android:resource="@xml/habits_widget_info" />
</receiver>
<receiver android:name=".RunsWidget" android:label="Running" android:exported="false">
  <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
  <meta-data android:name="android.appwidget.provider" android:resource="@xml/runs_widget_info" />
</receiver>
EOF
python3 - <<'PY'
p='android/app/src/main/AndroidManifest.xml'
s=open(p).read()
assert '</application>' in s
open(p,'w').write(s.replace('</application>',open('receivers.xml').read()+'</application>'))
PY
