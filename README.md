# Prompt Wheel

原生 macOS 小工具：**⌥ Space → 選取 Markdown prompt → 貼到原 App**。
SwiftUI + AppKit，沒有第三方套件。最低 macOS 15.2。

## Build / Run

需要 Swift 6 的 Xcode Command Line Tools 或 Xcode。

```sh
./scripts/build.sh
open "dist/Prompt Wheel.app"
```

這是 Swift package 專案，可用 Xcode 開啟 `Package.swift`。建置腳本會產出
完整的 `.app`、Info.plist 與 Markdown resources，並進行本機 ad-hoc 簽章。
請啟動 `.app`，不要用 `swift run PromptWheel`；未封裝的 binary 沒有 prompt resources。
`dist/` 是本機產物，不進版控。更新前請從選單列 Quit Prompt Wheel。

此版本供本機使用，未做 Developer ID 公證，未啟用 App Sandbox。
可設定 `PROMPT_WHEEL_SIGNING_IDENTITY` 使用自己的 code-signing identity。
保持 app 路徑穩定；ad-hoc 重建後 macOS 可能要求重新授予輔助使用權限。

## 使用

1. 啟動後在 macOS 選單列找到文字泡泡圖示。
2. 從選單列選 **Enable Accessibility…**，在系統設定 → 隱私權與安全性 →
   輔助使用，啟用 **Prompt Wheel**。必要時用 `+` 加入建置出的 `.app`。
3. 在 Codex、ChatGPT 或其他 App 中點選要輸入文字的欄位。
4. 按 **⌥ Space** 開啟透明、置頂的圓形 Prompt Wheel。拖曳中央圓心可移動圓盤；
   展開中的子選單會跟著移動，圓盤會留在可視螢幕內。游標停在分類上時會略微放大，
   並在同一視窗展開標題／摘要清單；移入 prompt 預覽全文，點擊 prompt 才會貼上。
   分類超過圓環可容納的數量時，選 **More +N** 開啟完整分類清單。
5. 鍵盤使用 **← / →** 切換分類、**↑ / ↓** 選取 prompt，**放開 Enter** 後貼上。
   **Escape** 取消。選單列的 **Manage Prompt Library…** 會開啟獨立視窗，
   用來新增、編輯、刪除、匯入與匯出 prompts。

App 只產生一次 Command-V，不產生 Enter，不自動送出。不要在選取時持續
壓住 Option 等修飾鍵；App 最多等待三秒，逾時會顯示錯誤。
一般文字輸入框是驗收對象；目標 App 自行限制貼上、唯讀或受保護的欄位
不會因為這個工具而變成可編輯。事件送出不代表能知道目標是否接受文字。

### ⌥ Space 衝突

ChatGPT macOS 預設也使用 ⌥ Space。若註冊失敗，選單列會顯示錯誤碼；
請先在衝突 App 的設定中改掉其綁定，再選 **Retry Global Hotkey**。
衝突時仍可用 **Open Prompt Wheel** 開啟圓環。Prompt Wheel 不會自動修改
其他 App，也不會偷偷換成別的快捷鍵。
其他事件監聽型快捷鍵工具可能不會造成 Carbon 註冊錯誤，仍需實際確認
按鍵沒有同時觸發它們。V1 快捷鍵固定，尚未提供自訂 shortcut recorder。

## Markdown library

第一次啟動會將 repository 的 `Prompts/` 範例複製到：

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

已有資料夾不會被覆寫。分類＝第一層資料夾名稱；prompt 名稱＝Markdown
檔名去掉副檔名；內容＝UTF-8 原文，保留換行與 code fence。
可自行新增分類。隱藏檔案、非 `.md` 檔案與更深層巢狀資料夾不載入。
每次開啟 panel 重新掃描，選取時重新讀檔；不需要重啟 app。

從選單列 **Manage Prompt Library…** 開啟獨立管理視窗，可新增、編輯、
重新分類與刪除 prompt。分類、標題和內文會直接儲存到目前的 Markdown
library；同名項目不會被覆寫。**匯入 JSON…** 和 **匯出 JSON…** 可備份或移轉
library；匯入時略過同名項目。匯入格式是
Prompt Wheel 匯出的 JSON 陣列，每筆含 `category`、`title`、`body`。

選取項目後也可按 **複製** 作為手動 fallback。它只會複製到剪貼簿，不會自動
貼上；按 Escape 關閉選單，再於目標輸入框按 ⌘V。成功或失敗都會明確顯示狀態。

選單列提供 **Open Prompt Folder…**、**Choose Prompt Folder…**，路徑會保存。
G/I/R/D 的分類快捷鍵尚未啟用，仍使用方向鍵切換分類。

## Clipboard

預設 **Restore Clipboard after Paste 關閉**，貼上後 clipboard 留下 prompt。
開啟時先保存所有可讀取的剪貼簿項目與格式，發出貼上事件約 0.9 秒後，
僅在剪貼簿仍未被其他操作更動時還原。遇到無法保存的格式，會在改動
剪貼簿前中止並提示。無法跨所有 App 保證讀取完成的時點，還原是 best effort；
若目標貼上速度慢，請保持此選項關閉。Escape 取消選單不會改動剪貼簿。

## Verification

```sh
./scripts/test.sh
./scripts/build.sh
```

Tests 使用暫存資料夾與私有 named pasteboard，不讀寫一般使用者剪貼簿。
涵蓋 library、按鍵選取狀態與多格式剪貼簿還原。這些不取代實際跨 App GUI
驗證。執行紀錄與待手動驗證項目見 `tasks/verification.md`。

規劃及 scope：`tasks/plan.md`。工作進度：`tasks/todo.md`。
