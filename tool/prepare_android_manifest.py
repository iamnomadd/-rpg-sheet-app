from pathlib import Path
import os

manifest = Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    raise SystemExit('AndroidManifest.xml não encontrado')

s = manifest.read_text(encoding='utf-8')
internet = '<uses-permission android:name="android.permission.INTERNET" />'
if internet not in s:
    marker = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
    s = s.replace(marker, marker + '\n    ' + internet, 1)

if 'android:scheme="rpgsheet"' not in s:
    end = s.find('</activity>')
    if end < 0:
        raise SystemExit('Activity principal não encontrada')
    intent = '''        <intent-filter android:autoVerify="false">
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data android:scheme="rpgsheet" android:host="auth-callback" />
        </intent-filter>
'''
    s = s[:end] + intent + s[end:]

manifest.write_text(s, encoding='utf-8')

keystore = os.environ.get('ANDROID_KEYSTORE_PATH', '').strip()
store_password = os.environ.get('ANDROID_KEYSTORE_PASSWORD', '').strip()
key_alias = os.environ.get('ANDROID_KEY_ALIAS', '').strip()
key_password = os.environ.get('ANDROID_KEY_PASSWORD', '').strip()

if all([keystore, store_password, key_alias, key_password]):
    Path('android/key.properties').write_text(
        'storePassword=' + store_password + '\n'
        'keyPassword=' + key_password + '\n'
        'keyAlias=' + key_alias + '\n'
        'storeFile=' + keystore.replace('\\', '/') + '\n',
        encoding='utf-8',
    )

    kts = Path('android/app/build.gradle.kts')
    groovy = Path('android/app/build.gradle')

    if kts.exists():
        g = kts.read_text(encoding='utf-8')
        if 'keystoreProperties' not in g:
            g = 'import java.util.Properties\nimport java.io.FileInputStream\n\n' + g
            g = g.replace(
                'android {\n',
                'android {\n'
                '    val keystoreProperties = Properties()\n'
                '    val keystorePropertiesFile = rootProject.file("key.properties")\n'
                '    if (keystorePropertiesFile.exists()) {\n'
                '        keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
                '    }\n',
                1,
            )
        if 'create("release")' not in g:
            g = g.replace(
                '    buildTypes {\n',
                '    signingConfigs {\n'
                '        create("release") {\n'
                '            keyAlias = keystoreProperties["keyAlias"] as String\n'
                '            keyPassword = keystoreProperties["keyPassword"] as String\n'
                '            storeFile = file(keystoreProperties["storeFile"] as String)\n'
                '            storePassword = keystoreProperties["storePassword"] as String\n'
                '        }\n'
                '    }\n\n'
                '    buildTypes {\n',
                1,
            )
        g = g.replace(
            'signingConfig = signingConfigs.getByName("debug")',
            'signingConfig = signingConfigs.getByName("release")',
        )
        kts.write_text(g, encoding='utf-8')
    elif groovy.exists():
        g = groovy.read_text(encoding='utf-8')
        if 'keystoreProperties' not in g:
            g = (
                "def keystoreProperties = new Properties()\n"
                "def keystorePropertiesFile = rootProject.file('key.properties')\n"
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
                "}\n\n" + g
            )
        if 'signingConfigs {' not in g:
            g = g.replace(
                '    buildTypes {\n',
                "    signingConfigs {\n"
                "        release {\n"
                "            keyAlias keystoreProperties['keyAlias']\n"
                "            keyPassword keystoreProperties['keyPassword']\n"
                "            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null\n"
                "            storePassword keystoreProperties['storePassword']\n"
                "        }\n"
                "    }\n\n"
                "    buildTypes {\n",
                1,
            )
        g = g.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.release')
        groovy.write_text(g, encoding='utf-8')
    else:
        raise SystemExit('build.gradle(.kts) não encontrado')

    print('Android preparado: manifest + assinatura release persistente')
else:
    print('Android preparado: manifest. Assinatura release não configurada (secrets ausentes).')
