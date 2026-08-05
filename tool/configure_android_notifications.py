from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Android template changed; missing {label}")
    return text.replace(old, new, 1)


manifest_path = Path("android/app/src/main/AndroidManifest.xml")
manifest = manifest_path.read_text(encoding="utf-8")
if "android.permission.RECEIVE_BOOT_COMPLETED" not in manifest:
    manifest = replace_once(
        manifest,
        "<application",
        '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
        "    <application",
        "manifest application tag",
    )
if "ScheduledNotificationReceiver" not in manifest:
    receivers = """        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
    manifest = replace_once(
        manifest,
        "    </application>",
        receivers + "    </application>",
        "manifest application end",
    )
manifest_path.write_text(manifest, encoding="utf-8")

gradle_path = Path("android/app/build.gradle.kts")
gradle = gradle_path.read_text(encoding="utf-8")
gradle = gradle.replace("JavaVersion.VERSION_11", "JavaVersion.VERSION_17")
if "isCoreLibraryDesugaringEnabled = true" not in gradle:
    gradle = replace_once(
        gradle,
        "    compileOptions {\n",
        "    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n",
        "compile options",
    )
if "multiDexEnabled = true" not in gradle:
    gradle = replace_once(
        gradle,
        "    defaultConfig {\n",
        "    defaultConfig {\n        multiDexEnabled = true\n",
        "default config",
    )
if "desugar_jdk_libs" not in gradle:
    gradle += """
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}
"""
elif "text-recognition-chinese" not in gradle:
    gradle = gradle.replace(
        'dependencies {\n',
        'dependencies {\n    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")\n',
        1,
    )
gradle_path.write_text(gradle, encoding="utf-8")
