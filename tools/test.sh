#!/bin/bash
# Audit: installs the minified release APK (throwaway key), launches it and records evidence.
set +e
OUT=artifacts/$1; mkdir -p "$OUT"
APK=android/app/build/outputs/apk/release/app-release.apk
PKG=az.ulduz8.app
adb wait-for-device; adb root; sleep 3; adb wait-for-device
adb shell getprop ro.build.version.sdk | tee "$OUT/sdk.txt"
adb shell dumpsys package com.android.chrome | grep -m1 versionName | tee "$OUT/chrome.txt"
# Key is throwaway, so skip asset-link check for Chrome only. Real link is verified separately against Google.
adb shell "echo '_ --disable-fre --no-default-browser-check --no-first-run --disable-digital-asset-link-verification-for-url=https://8ulduz.az' > /data/local/tmp/chrome-command-line"
adb shell chmod 644 /data/local/tmp/chrome-command-line
adb shell am set-debug-app --persistent com.android.chrome
adb install -r "$APK" 2>&1 | tee "$OUT/install.txt"
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS 2>&1 | tee "$OUT/grant.txt"
adb logcat -c
snap() { adb exec-out screencap -p > "$OUT/$1.png"; adb shell uiautomator dump /sdcard/u.xml >/dev/null 2>&1; adb exec-out cat /sdcard/u.xml > "$OUT/$1.xml"; adb shell dumpsys activity activities | grep -m3 -E "topResumedActivity|mResumedActivity|ResumedActivity" > "$OUT/$1.activity.txt"; }
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 2>&1 | tail -1 | tee "$OUT/launch.txt"
sleep 4; snap 1-splash
sleep 40; snap 2-home
adb shell input swipe 500 1500 500 500 400; sleep 3; snap 3-scrolled
adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://8ulduz.az/#/bolme/idman" $PKG 2>&1 | tee "$OUT/deeplink.txt"; sleep 12; snap 4-deeplink
adb shell input keyevent KEYCODE_BACK; sleep 4; snap 5-back
adb shell am start -S -a android.intent.action.MAIN -n $PKG/com.google.androidbrowserhelper.trusted.LauncherActivity -d "https://8ulduz.az/?utm_source=android#/secilmis" 2>&1 | tee "$OUT/shortcut.txt"; sleep 15; snap 6-shortcut
adb shell cmd shortcut get-shortcuts --flags 2 $PKG 2>&1 | head -40 > "$OUT/shortcuts.txt"
adb shell dumpsys shortcut 2>/dev/null | grep -A3 "Package: $PKG" | head -20 >> "$OUT/shortcuts.txt"
adb shell pm get-app-links $PKG 2>&1 | tee "$OUT/applinks.txt"
adb shell dumpsys package $PKG | grep -E "versionCode|versionName|targetSdk|minSdk|flags=|DEBUGGABLE|ALLOW_BACKUP|POST_NOTIFICATIONS" | head -14 | tee "$OUT/package.txt"
adb shell input keyevent KEYCODE_HOME; sleep 2
adb shell cmd statusbar expand-notifications; sleep 2; snap 7-shade; adb shell cmd statusbar collapse
adb shell am force-stop com.android.chrome; adb shell svc wifi disable; adb shell svc data disable; sleep 4
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 15; snap 8-offline
adb shell svc wifi enable; adb shell svc data enable
adb logcat -d > "$OUT/logcat.txt"
grep -E "FATAL EXCEPTION|ANR in|AndroidRuntime: Process: $PKG" "$OUT/logcat.txt" | head -20 | tee "$OUT/crashes.txt"
grep -iE "cr_TWA|TwaLauncher|Verification|OriginVerifier|Digital Asset|net::ERR|TrustedWeb" "$OUT/logcat.txt" | tail -40 > "$OUT/twa.txt"
echo DONE
