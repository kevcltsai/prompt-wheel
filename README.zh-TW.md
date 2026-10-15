# Prompt Wheel

[English](README.md) · **繁體中文**

**常用的 prompt，在 Mac 上任何 App 都是一個快捷鍵的距離。**

在任何輸入框按 **⌥ Space**，選一個 prompt，Prompt Wheel 就會把它貼回你原本的游標位置。只貼一次，絕不自動送出。你的 prompt library 就是一個裝滿 Markdown 檔的資料夾，完全由你掌握。

![Prompt Wheel：左邊是分類的彩色索引籤，右邊兩欄列出 prompt，底部是預覽](docs/screenshots/picker.png)

| 打字搜尋全部 prompt | 管理 Prompt Library |
| --- | --- |
| ![搜尋結果跨所有分類，色條標示來源分類](docs/screenshots/picker-search.png) | ![管理視窗：分類索引籤、prompt 清單與全文](docs/screenshots/library.png) |

<sub>截圖使用 App 內附的範例 prompts。</sub>

## 為什麼用 Prompt Wheel

如果你整天在 Codex、ChatGPT、Claude 或編輯器裡工作，一定會一直重打同樣的指示：「開始實作」、「review 這段 diff」、「找出 root cause」、「最後檢查」。Prompt Wheel 把它們收在同一個地方，讓你不用離開手上的 App，就能把它們放回正在輸入的地方。

- **在游標旁出現。** 小面板會在滑鼠旁打開，可以蓋在任何 App 上，任何桌面空間、全螢幕 App 也都可以用。
- **滑過就能瀏覽。** 每個分類是一張彩色索引籤，游標停在籤上就會顯示那個分類的 prompts，點一下 prompt 就貼上。
- **打字就能搜尋。** 面板一打開就可以直接打字，搜尋所有分類的標題和內文。注音、拼音等輸入法都能用。
- **只貼一次，不會送出。** Prompt Wheel 只會對你原本的 App 送出一次 ⌘V，絕不按 Return，你可以先修改再送出。
- **檔案就是原文。** 分類是資料夾，prompt 是 `.md` 檔。換行和 code fence 都照原樣貼上。
- **不擋路。** 可以把面板拖到旁邊，下次會在同一個位置打開。它住在選單列，不佔 Dock。
- **內建管理視窗。** 可以新增、編輯、改分類、刪除 prompt，也能把整個 library 匯入或匯出成 JSON。
- **原生、輕量。** 使用 SwiftUI + AppKit，沒有第三方套件，也不連網路。

## 安裝

Prompt Wheel 目前以原始碼發布，自己建置大約一分鐘。

**需求**

- macOS 15.2 以上
- Xcode，或含 Swift 6 的 Xcode Command Line Tools（`xcode-select --install`）

**1. 建置**

```bash
git clone https://github.com/kevcltsai/prompt-wheel.git
```

```bash
cd prompt-wheel && ./scripts/build.sh
```

會產生 `dist/Prompt Wheel.app`，並以本機 ad-hoc 方式簽章。

**2. 搬到「應用程式」資料夾**

```bash
mkdir -p ~/Applications && ditto "dist/Prompt Wheel.app" ~/Applications/"Prompt Wheel.app"
```

```bash
open ~/Applications/"Prompt Wheel.app"
```

選單列會出現一個對話泡泡圖示。

**3. 允許貼上（輔助使用權限）**

Prompt Wheel 需要「輔助使用」權限，才能貼到其他 App。

1. 點選單列圖示，選 **Enable Accessibility…**。
2. 在「**系統設定 → 隱私權與安全性 → 輔助使用**」打開 **Prompt Wheel**。清單裡沒有的話，按 **+** 加入 `~/Applications/Prompt Wheel.app`。
3. 從 Prompt Wheel 選單選 Quit，再重新打開它。

之後選單會顯示 **Accessibility: Granted…**。

### 更新

先結束 Prompt Wheel，然後 pull、重新建置，再照步驟 1–2 複製 App。每次在本機建置的簽章都不同，macOS 會把它當成新的 App。所以請在「輔助使用」裡移除舊的 **Prompt Wheel**，加入新的，再重新啟動。

如果不想每次更新都重新授權，可以在「鑰匙圈存取」建立一張自簽的「**程式碼簽署**」憑證，然後用它建置：

```bash
PROMPT_WHEEL_SIGNING_IDENTITY="你的憑證名稱" ./scripts/build.sh
```

### 移除

結束 Prompt Wheel，刪除 `~/Applications/Prompt Wheel.app`。你的 prompts 會保留在 `~/Library/Application Support/Prompt Wheel/Prompts/`，確定不需要時再刪除這個資料夾。

## 使用方式

1. 在 Codex、ChatGPT、Claude 或任何 App 裡點一下輸入框。
2. 按 **⌥ Space**。面板打開時，第一張分類籤剛好在游標底下。
3. 游標停在分類籤上就會打開那個分類，點一下也可以。
4. 移到某個 prompt 上，底部預覽區會顯示摘要，**點一下**就貼上。

| 按鍵 | 動作 |
| --- | --- |
| 直接打字 | 搜尋全部 prompt |
| ← / → | 上一個／下一個分類 |
| 1–9 | 跳到指定分類 |
| ↑ / ↓ | 選擇 prompt |
| Return（放開時） | 貼上選中的 prompt |
| Esc | 先清除搜尋，再按一次關閉 |

**移動面板：** 拖曳最上面那一行，或拖曳彩色邊框。Prompt Wheel 會記住它在這個螢幕上的位置。想恢復成在游標旁打開，從選單選 **Reset Picker Position**。

選單列的 **Manage Prompt Library…** 會打開獨立的管理視窗，可以新增、編輯、改分類、複製、刪除 prompt，也可以匯入或匯出 JSON。

### ⌥ Space 已經被佔用

ChatGPT macOS 版預設也使用 ⌥ Space。如果 Prompt Wheel 無法註冊這個快捷鍵，選單會顯示警告和錯誤碼。請先在那個 App 裡改掉它的快捷鍵，再選 **Retry Global Hotkey**。你隨時也可以從選單的 **Open Prompt Wheel** 打開面板。這個版本的快捷鍵固定是 ⌥ Space。

## 你的 prompt library

第一次啟動時，Prompt Wheel 會把範例 prompts 複製到：

```text
~/Library/Application Support/Prompt Wheel/Prompts/
├── GitHub/
│   ├── Repo Sync.md
│   └── Spec Cleanup.md
├── Implementation/
│   ├── Start Work.md
│   └── Final Check.md
├── Review/Code Review.md
├── Debug/Root Cause.md
└── General/Clarify Next Step.md
```

- 第一層的每個資料夾是一個**分類**，每個 `.md` 檔是一個 **prompt**，檔名去掉 `.md` 就是**標題**。
- 檔案的 UTF-8 內文會原樣貼上，不轉譯，也不刪減。
- 隱藏檔、非 `.md` 檔和更深層的子資料夾都不會載入。
- 每次打開面板都會重新掃描資料夾，所以你用自己的編輯器改檔案，會立刻反映出來。
- 已經存在的 library 不會被覆寫。可以用 **Choose Prompt Folder…** 改用別的資料夾，例如會同步的資料夾。
- 匯入時，分類和標題都相同的 prompt 會略過。JSON 格式是由 `{ "category", "title", "body" }` 組成的陣列。

## 剪貼簿

貼上時，prompt 會放在剪貼簿裡，預設會一直留著。

在選單打開 **Restore Clipboard after Paste**，貼上約 0.9 秒後，會把你原本的剪貼簿內容放回去。程式會先保存所有讀得到的格式。如果這段時間你又複製了新東西，就不會還原。有些 App 讀取剪貼簿比較慢，所以這個選項預設關閉。

## 隱私

Prompt Wheel 不連網路，也不收集任何資料。它只讀取你的 prompt 資料夾。你選了某個 prompt 時，它會把那段內容寫進剪貼簿，再對你原本在用的 App 送出一次 ⌘V。

## 開發

```bash
./scripts/test.sh
```

```bash
./scripts/build.sh
```

檢查程式不需要 Xcode 的測試執行器。它們使用暫存資料夾和私有剪貼簿，不會動到你真正的剪貼簿。請啟動建置出的 `.app`，不要用 `swift run`，因為單獨的執行檔沒有內附的 prompts 和字型。

設計說明見 [DESIGN.md](DESIGN.md)，產品簡介見 [PRODUCT.md](PRODUCT.md)。

## 授權

[MIT](LICENSE)。內附的 Barlow Condensed 字型依 SIL Open Font License 1.1 授權，見 [`App/Fonts/OFL.txt`](App/Fonts/OFL.txt)。
