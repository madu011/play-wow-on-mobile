#!/usr/bin/env python3
"""Add hardware-aware device diagnostics and one-tap native Winlator auto tuning."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "vendor" / "wow-mobile-engine"
JAVA = ENGINE / "app/src/main/java/com/winlator/wowmobile"
COMPANION = JAVA / "WowLKCompanionActivity.java"
HELPER = JAVA / "WowContainerHelper.java"

tuner = r'''package com.winlator.wowmobile;

import android.app.ActivityManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES20;
import android.util.DisplayMetrics;
import android.view.WindowManager;

import com.winlator.box64.Box64Preset;
import com.winlator.container.Container;
import com.winlator.container.DXWrappers;
import com.winlator.container.GraphicsDrivers;
import com.winlator.core.GPUHelper;

import java.util.HashMap;
import java.util.Map;

/** Reads actual Android graphics capabilities and applies a conservative WoW container profile. */
public final class WowLKAutoTuner {
    private WowLKAutoTuner() {}

    private static String glString(int name) {
        try {
            String value = GLES20.glGetString(name);
            return value == null ? "" : value;
        } catch (Exception ignored) {
            return "";
        }
    }

    private static Map<String, String> readEglInfo() {
        Map<String, String> values = new HashMap<>();
        EGLDisplay display = EGL14.EGL_NO_DISPLAY;
        EGLContext context = EGL14.EGL_NO_CONTEXT;
        EGLSurface surface = EGL14.EGL_NO_SURFACE;
        try {
            display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
            int[] version = new int[2];
            if (display == EGL14.EGL_NO_DISPLAY || !EGL14.eglInitialize(display, version, 0, version, 1)) {
                throw new IllegalStateException("EGL initialization unavailable");
            }
            int[] configAttrs = {
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_NONE
            };
            EGLConfig[] configs = new EGLConfig[1];
            int[] count = new int[1];
            if (!EGL14.eglChooseConfig(display, configAttrs, 0, configs, 0, 1, count, 0) || count[0] == 0) {
                throw new IllegalStateException("No compatible EGL config");
            }
            int[] contextAttrs = {EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE};
            context = EGL14.eglCreateContext(display, configs[0], EGL14.EGL_NO_CONTEXT, contextAttrs, 0);
            int[] surfaceAttrs = {EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE};
            surface = EGL14.eglCreatePbufferSurface(display, configs[0], surfaceAttrs, 0);
            if (context == EGL14.EGL_NO_CONTEXT || surface == EGL14.EGL_NO_SURFACE ||
                !EGL14.eglMakeCurrent(display, surface, surface, context)) {
                throw new IllegalStateException("Could not create graphics probe context");
            }
            values.put("gpuVendor", glString(GLES20.GL_VENDOR));
            values.put("gpuRenderer", glString(GLES20.GL_RENDERER));
            values.put("openGlVersion", glString(GLES20.GL_VERSION));
        } catch (Exception error) {
            values.put("gpuVendor", "Unavailable");
            values.put("gpuRenderer", "Unavailable");
            values.put("openGlVersion", "Unavailable");
            values.put("graphicsProbeError", error.getMessage() == null ? "EGL probe failed" : error.getMessage());
        } finally {
            if (display != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
                if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface);
                if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context);
                EGL14.eglTerminate(display);
            }
        }
        return values;
    }

    private static boolean hasVulkan(Context context) {
        PackageManager pm = context.getPackageManager();
        try {
            return pm.hasSystemFeature(PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL);
        } catch (Throwable ignored) {
            return false;
        }
    }

    private static int totalRamMb(Context context) {
        ActivityManager manager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo memory = new ActivityManager.MemoryInfo();
        manager.getMemoryInfo(memory);
        return (int) (memory.totalMem / (1024L * 1024L));
    }

    private static int availableRamMb(Context context) {
        ActivityManager manager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo memory = new ActivityManager.MemoryInfo();
        manager.getMemoryInfo(memory);
        return (int) (memory.availMem / (1024L * 1024L));
    }

    public static void addGraphicsInfo(Context context, Map<String, Object> info) {
        info.putAll(readEglInfo());
        boolean vulkan = hasVulkan(context);
        info.put("vulkanVersion", vulkan ? "Vulkan hardware feature reported by Android" : "Not reported by Android");
        info.put("vulkanLevel", vulkan ? "Supported (feature flag)" : "Not reported");
        info.put("graphicsApi", vulkan ? "Vulkan + OpenGL ES" : "OpenGL ES; Vulkan not reported");
        info.put("totalRamMb", totalRamMb(context));
        info.put("availableRamMb", availableRamMb(context));
        DisplayMetrics metrics = new DisplayMetrics();
        try {
            WindowManager wm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
            wm.getDefaultDisplay().getRealMetrics(metrics);
            info.put("screenResolution", metrics.widthPixels + " × " + metrics.heightPixels);
            info.put("screenDensityDpi", metrics.densityDpi);
        } catch (Exception ignored) {
            info.put("screenResolution", "Unavailable");
        }
    }

    private static boolean isAdreno(Context context) {
        try {
            return GPUHelper.getAdrenoModelId(context) > 0;
        } catch (Throwable ignored) {
            return false;
        }
    }

    private static Map<String, Object> profile(Context context) {
        int ram = totalRamMb(context);
        int cores = Runtime.getRuntime().availableProcessors();
        boolean vulkan = hasVulkan(context);
        boolean adreno = isAdreno(context);
        String gpu = readEglInfo().get("gpuRenderer");
        String graphicsDriver = (vulkan && adreno ? GraphicsDrivers.TURNIP : GraphicsDrivers.VORTEK)
            + "," + GraphicsDrivers.GLADIO;
        String dx = vulkan ? DXWrappers.DXVK : DXWrappers.WINED3D;
        String box64 = (ram < 5500 || cores <= 4) ? Box64Preset.CONSERVATIVE : Box64Preset.INTERMEDIATE;
        String resolution = (ram < 4000 || cores <= 4) ? "800x450" : "960x432";
        Map<String, Object> result = new HashMap<>();
        result.put("graphicsDriver", graphicsDriver);
        result.put("dxWrapper", dx);
        result.put("box64Preset", box64);
        result.put("screenSize", resolution);
        result.put("cpuCores", cores);
        result.put("totalRamMb", ram);
        result.put("gpuRenderer", gpu == null || gpu.isEmpty() ? "Unknown" : gpu);
        result.put("vulkanAvailable", vulkan);
        result.put("profile", (ram < 4000 || cores <= 4) ? "Conservative" : "Balanced");
        result.put("note", "Hardware-based starting profile. DXVK is selected only when Android reports Vulkan support; verify with a real game session.");
        return result;
    }

    public static Map<String, Object> apply(Context context) {
        Map<String, Object> result = profile(context);
        Container container = new WowContainerHelper(context).getContainer();
        if (container == null) {
            result.put("success", false);
            result.put("message", "WoW container has not been created yet. Launch/provision the runtime once, then apply Auto Configure.");
            return result;
        }
        container.setGraphicsDriver((String) result.get("graphicsDriver"));
        container.setDXWrapper((String) result.get("dxWrapper"));
        container.setBox64Preset((String) result.get("box64Preset"));
        container.setScreenSize((String) result.get("screenSize"));
        container.saveData();
        result.put("success", true);
        result.put("message", "Auto settings saved to the WoW Winlator container.");
        return result;
    }

    public static void applyToNewContainer(Context context, org.json.JSONObject data) throws org.json.JSONException {
        Map<String, Object> result = profile(context);
        data.put("graphicsDriver", result.get("graphicsDriver"));
        data.put("dxwrapper", result.get("dxWrapper"));
        data.put("box64Preset", result.get("box64Preset"));
        data.put("screenSize", result.get("screenSize"));
    }
}
'''
(JAVA / "WowLKAutoTuner.java").write_text(tuner, encoding="utf-8")

source = COMPANION.read_text(encoding="utf-8")
anchor = '''                case "getDeviceInfo":
                    result.success(readBasicDeviceInfo());
                    break;
'''
replacement = anchor + '''                case "applyAutoContainerSettings":
                    result.success(WowLKAutoTuner.apply(this));
                    break;
'''
if replacement not in source:
    if source.count(anchor) != 1:
        raise SystemExit("Could not find unique device-info channel insertion point")
    source = source.replace(anchor, replacement, 1)
anchor2 = '''        info.put("gpuVendor", "Not yet bridged");
        info.put("gpuRenderer", "Not yet bridged");
        info.put("openGlVersion", "Not yet bridged");
        info.put("vulkanVersion", "Not yet bridged");
        info.put("vulkanLevel", "Not yet bridged");
        info.put("graphicsApi", "Native engine device diagnostics available");
        info.put("screenResolution", "Not yet bridged");
        return info;
'''
replacement2 = '''        WowLKAutoTuner.addGraphicsInfo(this, info);
        return info;
'''
if replacement2 not in source:
    if source.count(anchor2) != 1:
        raise SystemExit("Could not find unique device-info placeholder block")
    source = source.replace(anchor2, replacement2, 1)
COMPANION.write_text(source, encoding="utf-8")

source = HELPER.read_text(encoding="utf-8")
anchor3 = '''            data.put("startupSelection", Container.STARTUP_SELECTION_AGGRESSIVE);
            manager.createContainerAsync(data, callback);
'''
replacement3 = '''            data.put("startupSelection", Container.STARTUP_SELECTION_AGGRESSIVE);
            WowLKAutoTuner.applyToNewContainer(context, data);
            manager.createContainerAsync(data, callback);
'''
if replacement3 not in source:
    if source.count(anchor3) != 1:
        raise SystemExit("Could not find unique new-container profile insertion point")
    source = source.replace(anchor3, replacement3, 1)
HELPER.write_text(source, encoding="utf-8")

print("WOW LK hardware scan and native Winlator auto-tuner installed.")
