# PotRemote — удалённое управление DAUM PotPlayer с iPhone

Проект состоит из двух частей:

1. **`server/potplayer_bridge.py`** — лёгкий HTTP-мост, который запускается на вашем ПК с Windows рядом с PotPlayer. Он принимает команды по локальной сети и передаёт их плееру через Win32-сообщения (официальный WM_USER API PotPlayer + эмуляция горячих клавиш).
2. **`ios/`** — исходники нативного iOS-приложения (SwiftUI, дизайн iOS 26 Liquid Glass: `glassEffect`, `GlassEffectContainer`, стили кнопок `.glass` / `.glassProminent`).

## Возможности

- Play / Pause / Stop, предыдущий / следующий элемент плейлиста
- Перемотка: слайдер по таймлайну, −10 c / +30 c
- Громкость и Mute
- Просмотр текущего плейлиста PotPlayer и запуск любого элемента
- Соотношение сторон: исходное, в окно, 4:3, 16:9, 1.85:1, 2.35:1
- Скорость воспроизведения (быстрее / медленнее / сброс)
- Полноэкранный режим
- Индикатор соединения, название текущего файла, тёмная Liquid Glass тема

---

## Шаг 1. Сервер на ПК

1. Установите Python 3.9+ (https://python.org). Сторонние библиотеки не нужны.
2. Откройте `server/potplayer_bridge.py` и при необходимости поправьте в `CONFIG`:
   - `potplayer_exe` — путь к `PotPlayerMini64.exe`;
   - `token` — задайте секрет, если хотите защитить доступ;
   - `port` — по умолчанию `9911`.
3. Запустите PotPlayer, затем сервер:
   ```
   python potplayer_bridge.py
   ```
4. Разрешите входящие подключения на порт 9911 в брандмауэре Windows
   (или при первом запуске согласитесь в диалоге Windows Defender).
5. Узнайте IP ПК в локальной сети: `ipconfig` → IPv4-адрес (например `192.168.1.100`).

**Проверка:** откройте в браузере `http://<IP_ПК>:9911/status` — должен вернуться JSON со статусом плеера.

### Важно про WM_COMMAND ID (соотношение сторон)

Команды меню (аспект и т.п.) отправляются по числовым ID в таблице `WM_COMMAND_IDS`.
Эти ID **могут отличаться между версиями PotPlayer**. Если какая-то кнопка аспекта
не срабатывает:

1. Откройте PotPlayer → Настройки (F5) → «Клавиши/Управление» — в списке команд видны их номера.
2. Впишите правильные номера в `WM_COMMAND_IDS` и перезапустите сервер.
3. Для быстрой проверки ID есть отладочный эндпоинт:
   `POST /command` с телом `{"id": 10204}`.

Базовые функции (play/pause/seek/громкость/след./пред./скорость/полный экран)
работают через стабильный WM_USER API и стандартные горячие клавиши — их править не нужно.

Также рекомендуется включить в PotPlayer режим «Одно окно» (single instance),
чтобы запуск элемента плейлиста открывался в текущем экземпляре плеера.

---

## Шаг 2. Сборка iOS-приложения

Собрать `.ipa` можно только в Xcode на macOS с вашим сертификатом разработчика —
готовый бинарник в этот архив не входит (подпись привязана к вашему аккаунту).

### Вариант А — через XcodeGen (быстрее)

```bash
brew install xcodegen
cd ios
# отредактируйте project.yml: DEVELOPMENT_TEAM и PRODUCT_BUNDLE_IDENTIFIER
xcodegen generate
open PotRemote.xcodeproj
```

### Вариант Б — вручную в Xcode

1. Xcode 26 → File → New → Project → iOS App, имя `PotRemote`, интерфейс SwiftUI, минимальная версия iOS 26.
2. Удалите сгенерированный `ContentView.swift`, перетащите в проект все файлы из `ios/PotRemote/` (включая папку `Views`).
3. В настройках таргета → Info добавьте ключи из `Info.plist`
   (`NSLocalNetworkUsageDescription` и `NSAppTransportSecurity → NSAllowsLocalNetworking`).
4. Signing & Capabilities → выберите вашу команду разработчика.

### Получение .ipa

- **Просто на свой iPhone:** подключите iPhone 15 Pro кабелем, выберите его как
  Run Destination и нажмите Run — приложение установится напрямую, `.ipa` не нужен.
- **Именно файл .ipa:** Product → Archive → Distribute App → *Debugging* / *Release Testing*
  (Ad Hoc) → Export. Либо из командной строки:
  ```bash
  xcodebuild -project PotRemote.xcodeproj -scheme PotRemote \
    -configuration Release -archivePath build/PotRemote.xcarchive archive
  xcodebuild -exportArchive -archivePath build/PotRemote.xcarchive \
    -exportPath build/ipa -exportOptionsPlist ExportOptions.plist
  ```

## Шаг 3. Первый запуск

1. Откройте приложение → вкладка «Настройки» → введите IP ПК и порт → «Проверить соединение».
2. Разрешите приложению доступ к локальной сети (системный запрос iOS появится один раз).
3. Вкладка «Плеер» — транспорт, перемотка, громкость; «Плейлист» — список файлов;
   «Управление» — аспект, скорость, полный экран.

## API моста (для расширения)

| Метод | Путь             | Тело                              | Описание                    |
|-------|------------------|-----------------------------------|-----------------------------|
| GET   | /status          | —                                 | Статус, позиция, громкость  |
| GET   | /playlist        | —                                 | Текущий плейлист (.dpl)     |
| POST  | /toggle …        | —                                 | play/pause/stop/next/prev/fullscreen/mute/speed_up/speed_down/speed_reset |
| POST  | /seek            | {"position_ms": N} или {"relative_ms": N} | Перемотка          |
| POST  | /volume          | {"level": 0–100}                  | Громкость                   |
| POST  | /aspect          | {"name": "16_9"}                  | Соотношение сторон          |
| POST  | /playlist/play   | {"index": N}                      | Запуск элемента плейлиста   |
| POST  | /command         | {"id": N}                         | Произвольный WM_COMMAND     |
