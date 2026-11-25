package com.winlator.wowmobile;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.InputDevice;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.core.content.FileProvider;
import androidx.preference.PreferenceManager;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Collects privacy-filtered diagnostics after a failed or disconnected game session. */
public class WowDiagnosticsActivity extends Activity {
    private TextView output;
    private Button collect;
    private File latestReport;

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(24, 20, 24, 20);
        root.setBackgroundColor(0xFF0B1422);

        TextView title = new TextView(this);
        title.setText("WOW LK • CONNECTION DIAGNOSTICS");
        title.setTextColor(0xFFE2B45D);
        title.setTextSize(20);
        title.setPadding(0, 0, 0, 12);
        root.addView(title);

        TextView note = new TextView(this);
        note.setText("Run this after a realm disconnect or game crash. The report includes device/network details, realm DNS and TCP checks, and filtered app logs. Passwords and account credentials are excluded.");
        note.setTextColor(0xFFB8C6D8);
        note.setTextSize(14);
        note.setPadding(0, 0, 0, 16);
        root.addView(note);

        collect = new Button(this);
        collect.setText("COLLECT LOG REPORT");
        collect.setOnClickListener(v -> collectReport());
        root.addView(collect);

        Button share = new Button(this);
        share.setText("SHARE LATEST REPORT");
        share.setOnClickListener(v -> shareReport());
        root.addView(share);

        ScrollView scroll = new ScrollView(this);
        output = new TextView(this);
        output.setText("No report collected yet.");
        output.setTextColor(0xFFEAF0F8);
        output.setTextSize(12);
        output.setPadding(0, 18, 0, 12);
        scroll.addView(output);
        root.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
        setContentView(root);
    }

    private void collectReport() {
        collect.setEnabled(false);
        output.setText("Collecting diagnostics…");
        Executors.newSingleThreadExecutor().execute(() -> {
            String report = buildReport();
            try {
                File dir = new File(getFilesDir(), "diagnostics");
                if (!dir.exists() && !dir.mkdirs()) throw new Exception("Cannot create diagnostics folder");
                String stamp = new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date());
                File file = new File(dir, "wowlk-diagnostic-" + stamp + ".txt");
                try (FileOutputStream stream = new FileOutputStream(file)) {
                    stream.write(report.getBytes(StandardCharsets.UTF_8));
                }
                latestReport = file;
                runOnUiThread(() -> {
                    collect.setEnabled(true);
                    output.setText(report);
                    Toast.makeText(this, "Diagnostic report created.", Toast.LENGTH_LONG).show();
                });
            } catch (Exception error) {
                runOnUiThread(() -> {
                    collect.setEnabled(true);
                    output.setText(report + "\n\nREPORT SAVE ERROR: " + error);
                });
            }
        });
    }

    private String buildReport() {
        StringBuilder out = new StringBuilder();
        out.append("WOW LK DIAGNOSTIC REPORT\n");
        out.append("Generated: ").append(new Date()).append("\n");
        out.append("App package: ").append(getPackageName()).append("\n");
        out.append("Android: ").append(Build.VERSION.RELEASE).append(" (SDK ").append(Build.VERSION.SDK_INT).append(")\n");
        out.append("Device: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append("\n");
        out.append("Build: ").append(Build.DISPLAY).append("\n");
        appendInputDevices(out);
        out.append("\n");

        SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(this);
        String gamePath = prefs.getString(WowMobileActivity.PREF_GAME_FOLDER, "");
        out.append("Game folder configured: ").append(gamePath.isEmpty() ? "No" : "Yes").append("\n");
        out.append("Game folder exists: ").append(!gamePath.isEmpty() && new File(gamePath).isDirectory()).append("\n");
        String realm = readRealm(gamePath);
        out.append("Configured realmlist: ").append(realm.isEmpty() ? "Not found" : realm).append("\n");

        out.append("\nNETWORK\n");
        out.append("Transport: ").append(networkType()).append("\n");
        String host = extractHost(realm);
        if (!host.isEmpty()) {
            out.append("Realm host: ").append(host).append("\n");
            try {
                long start = System.currentTimeMillis();
                InetAddress[] addresses = InetAddress.getAllByName(host);
                out.append("DNS: OK (").append(System.currentTimeMillis() - start).append(" ms)\n");
                for (InetAddress address : addresses) out.append("Resolved IP: ").append(address.getHostAddress()).append("\n");
            } catch (Exception error) {
                out.append("DNS: FAILED - ").append(safe(error.toString())).append("\n");
            }
            out.append("TCP logon port 3724: ").append(testTcp(host, 3724)).append("\n");
        } else {
            out.append("DNS/TCP checks skipped: no hostname found in realmlist.wtf\n");
        }

        out.append("\nANDROID LOGCAT (recent; filtered for WoW/runtime/network failures)\n");
        out.append(readFilteredLogcat());
        out.append("\nAPP-ACCESSIBLE WINE / BOX64 / RUNTIME LOG FILES\n");
        out.append(appendRuntimeFiles());
        out.append("\nEND OF REPORT\n");
        return out.toString();
    }


    /** Lists Android input devices and their advertised sources for hardware troubleshooting. */
    private void appendInputDevices(StringBuilder out) {
        out.append("\nINPUT DEVICES\n");
        int[] ids = InputDevice.getDeviceIds();
        if (ids == null || ids.length == 0) {
            out.append("No Android input devices reported.\n");
            return;
        }
        for (int id : ids) {
            InputDevice device = InputDevice.getDevice(id);
            if (device == null) continue;
            out.append("Device: ").append(safe(device.getName()))
                    .append(" (id ").append(id).append(")\n");
            out.append("  Type: ").append(device.isVirtual() ? "Virtual" : "Physical / built-in")
                    .append("; keyboard type: ").append(keyboardType(device.getKeyboardType())).append("\n");
            out.append("  Sources:");
            boolean any = false;
            if (device.supportsSource(InputDevice.SOURCE_KEYBOARD)) { out.append(" KEYBOARD"); any = true; }
            if (device.supportsSource(InputDevice.SOURCE_MOUSE)) { out.append(" MOUSE"); any = true; }
            if (device.supportsSource(InputDevice.SOURCE_GAMEPAD)) { out.append(" GAMEPAD"); any = true; }
            if (device.supportsSource(InputDevice.SOURCE_JOYSTICK)) { out.append(" JOYSTICK"); any = true; }
            if (!any) out.append(" other");
            out.append("\n");
        }
    }

    private String keyboardType(int type) {
        if (type == InputDevice.KEYBOARD_TYPE_ALPHABETIC) return "Alphabetic";
        if (type == InputDevice.KEYBOARD_TYPE_NON_ALPHABETIC) return "Non-alphabetic";
        return "None";
    }

    private String networkType() {
        try {
            ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
            if (cm == null) return "Unavailable";
            Network network = cm.getActiveNetwork();
            if (network == null) return "No active network";
            NetworkCapabilities caps = cm.getNetworkCapabilities(network);
            if (caps == null) return "Connected (capabilities unavailable)";
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return "Wi-Fi";
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) return "Mobile data";
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) return "Ethernet";
            return "Other network";
        } catch (Exception error) { return "Unavailable: " + safe(error.toString()); }
    }

    private String readRealm(String gamePath) {
        if (gamePath == null || gamePath.isEmpty()) return "";
        File data = new File(gamePath, "Data");
        File[] locales = data.listFiles();
        if (locales == null) return "";
        for (File locale : locales) {
            File file = new File(locale, "realmlist.wtf");
            if (!file.isFile()) continue;
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                    new java.io.FileInputStream(file), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    Matcher matcher = Pattern.compile("(?i)^\\s*set\\s+realmlist\\s+[\\\"]?([^\\\"]+)").matcher(line.trim());
                    if (matcher.find()) return matcher.group(1).trim();
                }
            } catch (Exception ignored) {}
        }
        return "";
    }

    private String extractHost(String value) {
        if (value == null) return "";
        String host = value.trim().replaceFirst("(?i)^https?://", "").split("[/:\\s]")[0];
        return host.matches("[A-Za-z0-9.-]+") ? host : "";
    }

    private String testTcp(String host, int port) {
        try (Socket socket = new Socket()) {
            long start = System.currentTimeMillis();
            socket.connect(new InetSocketAddress(host, port), 2500);
            return "CONNECTED (" + (System.currentTimeMillis() - start) + " ms)";
        } catch (Exception error) { return "FAILED - " + safe(error.toString()); }
    }

    private String readFilteredLogcat() {
        StringBuilder result = new StringBuilder();
        Process process = null;
        try {
            process = Runtime.getRuntime().exec(new String[]{"logcat", "-b", "all", "-d", "-v", "threadtime", "-t", "2200"});
            int count = 0;
            Pattern useful = Pattern.compile("(?i)(winlator|wow|wine|wineserver|box64|realm|realmlist|worldserver|authserver|dns|socket|connect|disconnect|timeout|fatal|exception|crash|error|warn|vulkan|egl|dxvk|opengl|xserver|guestprogram|processhelper)");
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null && count < 350) {
                    if (!useful.matcher(line).find()) continue;
                    result.append(redact(line)).append("\n");
                    count++;
                }
            }
            process.waitFor(3, java.util.concurrent.TimeUnit.SECONDS);
            if (count == 0) result.append("No matching app/runtime log lines were available.\n");
        } catch (Exception error) {
            result.append("Logcat unavailable: ").append(safe(error.toString())).append("\n");
        } finally {
            if (process != null) process.destroy();
        }
        return result.toString();
    }

    /**
     * Copies only small, text-like runtime log files from this app's private and app-specific
     * external directories. It never scans arbitrary shared storage or includes config files.
     */
    private String appendRuntimeFiles() {
        StringBuilder out = new StringBuilder();
        ArrayList<File> candidates = new ArrayList<>();
        collectRuntimeLogCandidates(getFilesDir(), candidates, 0);
        File external = getExternalFilesDir(null);
        if (external != null) collectRuntimeLogCandidates(external, candidates, 0);
        candidates.sort(Comparator.comparingLong(File::lastModified).reversed());
        int files = 0;
        long totalBytes = 0;
        for (File file : candidates) {
            if (files >= 15 || totalBytes >= 1024 * 1024) break;
            long size = file.length();
            if (size <= 0 || size > 256 * 1024 || totalBytes + size > 1024 * 1024) continue;
            out.append("\n--- ").append(file.getName()).append(" (")
                    .append(size).append(" bytes; modified ").append(new Date(file.lastModified()))
                    .append(") ---\n");
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                    new java.io.FileInputStream(file), StandardCharsets.UTF_8))) {
                String line;
                int lines = 0;
                while ((line = reader.readLine()) != null && lines < 500) {
                    out.append(redact(line)).append("\n");
                    lines++;
                }
                totalBytes += size;
                files++;
            } catch (Exception error) {
                out.append("Could not read file: ").append(safe(error.toString())).append("\n");
            }
        }
        if (files == 0) out.append("No app-accessible Wine/Box64/runtime log files found. Android logcat above may still contain runtime diagnostics.\n");
        else out.append("\nIncluded ").append(files).append(" file(s), ").append(totalBytes).append(" bytes total.\n");
        return out.toString();
    }

    private void collectRuntimeLogCandidates(File directory, ArrayList<File> output, int depth) {
        if (directory == null || depth > 6 || output.size() >= 80) return;
        File[] entries = directory.listFiles();
        if (entries == null) return;
        for (File entry : entries) {
            if (output.size() >= 80) return;
            if (entry.isDirectory()) {
                if (!entry.getName().startsWith(".") && !entry.getName().equalsIgnoreCase("cache"))
                    collectRuntimeLogCandidates(entry, output, depth + 1);
                continue;
            }
            if (!entry.isFile()) continue;
            String name = entry.getName().toLowerCase(Locale.ROOT);
            boolean textLike = name.endsWith(".log") || name.endsWith(".txt") ||
                    name.contains("logcat") || name.contains("stdout") || name.contains("stderr");
            boolean runtimeName = name.contains("wine") || name.contains("box64") ||
                    name.contains("wineserver") || name.contains("xserver") ||
                    name.contains("dxvk") || name.contains("vulkan") ||
                    name.contains("crash") || name.contains("runtime");
            if (textLike && runtimeName && entry.length() <= 256 * 1024) output.add(entry);
        }
    }

    private String redact(String line) {
        return line.replaceAll("(?i)(password|passwd|username|account|token|authorization|session)(\\s*[:=]\\s*)[^\\s,;]+", "$1$2[REDACTED]");
    }

    private String safe(String value) {
        return value == null ? "unknown" : value.replaceAll("[\\r\\n]", " ");
    }

    private void shareReport() {
        if (latestReport == null || !latestReport.isFile()) {
            Toast.makeText(this, "Collect a report first.", Toast.LENGTH_SHORT).show();
            return;
        }
        Uri uri = FileProvider.getUriForFile(this, getPackageName() + ".FileProvider", latestReport);
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType("text/plain");
        send.putExtra(Intent.EXTRA_SUBJECT, "WOW LK disconnect diagnostic report");
        send.putExtra(Intent.EXTRA_STREAM, uri);
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        startActivity(Intent.createChooser(send, "Share diagnostic report"));
    }
}
