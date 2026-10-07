# Android (APK) — legado

O RPG Sheet começou como app Android (APK), mas hoje o alvo principal é **Flutter Web/PWA**. O build de APK é legado e não faz parte do fluxo atual de publicação.

- Não há pasta `android/` no repositório. O workflow antigo a gerava com `flutter create . --platforms=android` durante o build.
- `build-apk-signed.yml`: workflow antigo de build do APK assinado. Ele não está em `.github/workflows/` e, por isso, não roda. Ele também dependia dos zips `rpg_sheet_app_v*.zip` na raiz, hoje arquivados em `docs/archive/zips/`.
- `prepare_android_manifest.py`: script usado por esse workflow para ajustar o `AndroidManifest.xml`. O workflow ainda o chama pelo caminho antigo `tool/prepare_android_manifest.py`.

Os arquivos foram mantidos sem alteração, apenas como referência histórica. Não os use como referência do estado atual do projeto.
