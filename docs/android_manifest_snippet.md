# Android OAuth deep link snippet

把以下 `<intent-filter>` 加到 `android/app/src/main/AndroidManifest.xml` 的主 `activity` 內：

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="tw.mingde.transport"
        android:host="login-callback" />
</intent-filter>
```

Supabase Auth redirect URL 對應為：

```text
tw.mingde.transport://login-callback/
```
