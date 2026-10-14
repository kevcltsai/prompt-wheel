# Prompt Wheel → Claude 交接

核對日期：2026-10-11（Asia/Taipei）。
本次任務只準備交接；沒有修改產品程式、安裝／啟動 App、執行 GUI、讀寫一般剪貼簿、改權限或提交 Git。本文不是恢復先前暫停開發工作的授權。

## 先讀這段

**目前專案資料夾不是已安裝 build 10 的完整來源。** 本機主工作區停在 build 2 的未提交功能；已安裝 App 是 build 10。歷史交接指出 build 10 在暫存 worktree A 開發，但本次核對 A/B/C 路徑皆不存在，只有 Git worktree 登記殘留。

Claude 第一階段應以唯讀方式找回 build 10 完整來源與正式驗收文件、核對 dirty 差異，再提出接續工作。不應直接以主工作區 build/install 覆蓋現有 App。找到同名分支或相同 HEAD 不代表找回未提交程式。

## 1. 即時基準與版本差異

Codex App 專案設定：
- Project：Prompt Wheel，ID `46a9405b-a227-4f57-b3ef-05c0168f4740`。
- 設定路徑、實際 cwd 與 Git root 均為 `/Users/kevintsai/Documents/Projects/Prompt Wheel`。
- Branch：`feat/prompt-wheel-library-ring`。
- HEAD：`399569d868b6704b3b41bb7834694110038ae04e`。
- Remote：`git remote -v` 無輸出。未查到可核對的公開發布來源；不要宣稱與遠端同步。
- `main` 和登記的 A/B/C 分支目前都指向同一 HEAD。
- 近期歷史：`399569d` 驗證文件；`a0bd25b` 原始 MVP；`5d3a818` 初版計畫。

| 物件 | 本次直接讀取結果 | 意義 |
| --- | --- | --- |
| 主工作區 App/Info.plist | 0.1.0，build 2，ID `pw-2026-10-05-mouse-diagnostics-01` | 目前原始碼設定 |
| 主工作區 dist/Prompt Wheel.app | 同上 | 舊建置產物，不能當最新安裝版 |
| ~/Applications/Prompt Wheel.app | 0.1.0，build 10，ID `pw-2026-10-07-clipboard-preservation-01` | 已安裝檔案；本次未確認執行中的 process |

執行檔 SHA-256（本次重新計算）：
- dist：`772c8a3636319d80f1538e74abdd81c08e4f323a556147a2905490e647ad670c`
- installed：`f153456e791d055f85c9e909394038daeb8821e327c4b6b79ea1bd384ea04a8a`

已安裝 build 10 的 Info.plist 沒有主工作區仍保留的 `LSUIElement=true`。這也與歷史「加入一般主視窗」的交接一致；不得把舊 menu-bar-only 架構描述當作 build 10 的全部行為。

### 主工作區必須保留的內容

8 個 tracked 修改：
- App/Info.plist
- README.md
- Sources/PromptWheel/PromptPanel.swift
- Sources/PromptWheel/PromptWheelApp.swift
- Sources/PromptWheelCore/PromptLibrary.swift
- Tests/PromptWheelChecks/Checks.swift
- tasks/todo.md
- tasks/verification.md

6 個原有 untracked Swift 檔：
- Sources/PromptWheel/PromptLibraryWindow.swift
- Sources/PromptWheelCore/PanelInputDiagnostics.swift
- Sources/PromptWheelCore/PromptWheelBuildIdentity.swift
- Sources/PromptWheelCore/WheelCategoryLayout.swift
- Sources/PromptWheelCore/WheelCategoryNavigation.swift
- Sources/PromptWheelCore/WheelPanelGeometry.swift

tracked diff 統計為 1,233 additions / 90 deletions，不含 untracked 檔。交接文件本身為本次新增。不可只傳 Git commit／tracked patch，否則會遺失必要來源。

### 已登記但本次無法存取的 worktree

| 舊路徑 | branch |
| --- | --- |
| /private/tmp/dot-prompt-parallel-20261006/A | codex/prompt-wheel-A-hover |
| /private/tmp/dot-prompt-parallel-20261006/B | codex/prompt-wheel-B-window |
| /private/tmp/dot-prompt-parallel-20261006/C | codex/prompt-wheel-C-paste |

本次 `test -d` 均為 false。不要 prune／reset／clean 這些登記或據此斷言資料永久遺失；先查備份、原執行環境或歷史留存。

## 2. 產品用途與已知設計

Prompt Wheel 是本機 macOS 提示詞工具。使用者在一般可編輯欄位中按 ⌥ Space，選 Markdown prompt，將原文貼回原 App 一次，且不自動送出。

主工作區可直接確認：
- Swift 6 package，SwiftUI + AppKit + Carbon + ApplicationServices，無第三方套件；最低 macOS 15.2 為宣告值。
- 分類來自第一層資料夾，prompt 來自 UTF-8 Markdown 檔；每次開啟重新掃描，選取時重新讀取。
- 預設資料夾：`~/Library/Application Support/Prompt Wheel/Prompts/`；只在不存在時 seed，不覆寫使用者 library。自訂路徑存在 UserDefaults 的 `promptFolder`。
- 透明浮動圓環；hover 分類展開同一 panel 的子選單；中心可拖曳；More 處理超額分類。Reduce Transparency 有不透明 fallback。
- 獨立 Prompt Library 視窗提供 CRUD、改分類、JSON 匯入／匯出與手動複製；同名匯入略過。
- ←/→ 切分類、↑/↓ 選 prompt、Enter key-up 選取、Escape 取消；不合成 Return。
- 原 App 身分在顯示 panel 前記錄；貼上需權限、放開修飾鍵、確認 target activation 與 clipboard ownership，再向目標 PID 發一次 Command-V。
- 主工作區剪貼簿還原預設關閉；開啟時保存可讀 item/formats，約 0.9 秒後在 changeCount 仍屬於本次寫入時嘗試還原。這是 build 2 來源行為，不推定 build 10 完全相同。
- ⌥ Space 衝突可顯示註冊錯誤並重試；選單提供 Open Prompt Wheel fallback。

build 10 的歷史交接另記錄一般主視窗、preview／paste 路徑、transaction/rollback 與權限診斷。來源尚未找回，先將這些當歷史線索；不要从 build ID 猜測實作細節。

## 3. 程式與文件導航

| 想查的問題 | 主工作區入口 |
| --- | --- |
| 啟動、status menu、target capture、貼上任務 | Sources/PromptWheel/PromptWheelApp.swift |
| 輪盤、AppKit 事件、hover、拖曳、按鍵 | Sources/PromptWheel/PromptPanel.swift |
| 管理視窗與 editor | Sources/PromptWheel/PromptLibraryWindow.swift |
| 全域快捷鍵／設定 | Sources/PromptWheel/GlobalHotKey.swift、Settings.swift |
| 目標啟用、CGEvent 貼上、permission | Sources/PromptWheel/PasteController.swift |
| 掃描／CRUD／JSON／path validation | Sources/PromptWheelCore/PromptLibrary.swift |
| 多格式剪貼簿 snapshot | Sources/PromptWheelCore/ClipboardSnapshot.swift |
| 狀態與幾何檢查 | Sources/PromptWheelCore/MenuNavigation.swift、WheelCategory*.swift、WheelPanelGeometry.swift |
| build identity 與記憶體事件計數 | Sources/PromptWheelCore/PromptWheelBuildIdentity.swift、PanelInputDiagnostics.swift |
| 核心檢查 | Tests/PromptWheelChecks/Checks.swift |
| 建置、測試、bundle | Package.swift、scripts/build.sh、scripts/test.sh、App/Info.plist |
| 用法與歷史驗證 | README.md、tasks/todo.md、tasks/verification.md |

`tasks/plan.md` 是最初 grouped-list MVP 規劃，部分內容已被後續 radial wheel 與主視窗工作取代。主工作區 verification 只到 2026-10-06 build 2 診斷階段，不涵蓋 build 10 的所有工作。

build 10 舊交接列出的額外檔案（尚未在目前主工作區找回）：
- Sources/PromptWheel/PromptWheelMainWindow.swift
- Sources/PromptWheelCore/PastePermissionDiagnostics.swift
- Sources/PromptWheelCore/PromptPasteDelivery.swift
- Sources/PromptWheelCore/PromptWheelMainWindowLifecycle.swift
- Sources/PromptWheelCore/WheelSubmenuCollapseSchedule.swift
- tasks/prompt-wheel-spec-v1.md
- tasks/prompt-wheel-acceptance-v1.md
- tasks/prompt-wheel-test-plan-v1.md
- tasks/prompt-wheel-work-plan-v1.md
- tasks/prompt-wheel-spec-reviews.md、tasks/drafts/

A worktree 當時也改過 PasteController、ClipboardSnapshot、scripts/test.sh 等 tracked 檔；找回來源時要比完整樹，不能只補上述新檔。

## 4. 證據狀態與未完成項目

**本次直接確認：** App 專案設定、Git 基準、dirty 清單、缺失 worktree 路徑、兩份 bundle 的 plist 與執行檔 hash。`git diff --check` 與 `plutil -lint App/Info.plist` 通過。本次沒有重跑 build、behavior tests、codesign 或 GUI。

**主工作區歷史紀錄：** 原始 MVP 23 checks，後續逐步增加到 build 2 的 53 checks，曾 build/sign 通過；只能引用為各當時候選的歷史證據。不能把它們當 build 10 或目前重新建置的測試結果。

**後續對話紀錄（本次重新讀取，但原始實測不在本輪）：**
- build 10 handoff 的候選 hash 與本次已安裝 hash 完全相同。
- 「接續 Prompt Wheel 驗證」記錄使用者確認實體 ⌥Space 開啟 wheel、Escape 關閉；明確沒有原始截圖或 auditor 親自觀察。不能延伸為 prompt 選取、貼上、focus、欄位仍空白或 clipboard 通過。
- 歷史提到 92 backend / 9 private-board checks；本次未取得完整 build 10 logs，不當成已重新核對的 PASS。
- 貼上一次、no-send、跨 App focus、general clipboard 全格式保全與獨立 cleanup 仍未完整驗收。
- build 10 重開後 AX／CG permission 的當時讀值未知；本次也未知。工具 timeout 不證明 Mac 上鎖或權限拒絕。
- 後续執行與審查對話最後均記錄工作已暫停，不自動恢復。

歷史正式驗收要求 general clipboard 測試前有全格式保存及獨立清理；當時工具能力不足。這是**自動化正式驗收的證據缺口**，不等於產品沒有 snapshot 實作，也不禁止使用者自行使用產品。後續 auditor 明確區分：使用者本人在普通欄位的貼上/no-send 回報可作有限證據，但不能取代完整正式 AC。請找回正式文件後再沿用精確條件，避免把舊工具限制變成永久產品阻擋。

## 5. Claude 的接手順序

1. 重新核對專案路徑、Git status、worktree、安裝版 identity/hash，完成目前狀態表。保留所有現有 dirty/untracked 內容。
2. 先找回 A 的 build 10 完整 tracked/untracked 來源與四份正式 spec/AC/test/work plan。可從下面的歷史對話、原環境或備份取回；若只有 build 6 片段，標示不完整。找不到時列出缺件，不假裝目前主工作區等於 build 10。
3. 比較找回來源與主工作區，提出要保留／整合的具體差異。任何復原或寫入都以使用者接續授權為準；本文件不授權覆蓋安裝版、清除 worktree、commit、push 或發布。
4. 在使用者指定後續任務後，使用正確候選的建置／測試入口做必要回歸。只在變更、失敗或新疑點需要時重跑。
5. 如恢復 GUI 驗收，先確認唯一操作桌面的執行者與正確 app process。依候選逐項記錄 hover/click/drag、視窗 lifecycle、physical hotkey、Escape、跨 App exact paste/no-send、權限恢復、clipboard 與多螢幕。以 UI／使用者回報／source／fixture 各自標示，不混算。
6. 回覆繁體中文、先給簡短計畫；已授權範圍內自主完成及 review，不要求逐步確認。重大來源差異或真實權限阻擋才解釋原因。保留原始資料與既有 library。

主工作區 build 2 的入口如下；**先完成來源對齊，再決定是否執行**：
```sh
cd "/Users/kevintsai/Documents/Projects/Prompt Wheel"
./scripts/test.sh
./scripts/build.sh
```

build 腳本產生 `dist/Prompt Wheel.app` 並 ad-hoc 簽章；不要用未封裝的 `swift run PromptWheel` 代替 app。建置會寫入 .build/dist，且腳本使用 SwiftPM --disable-sandbox；執行環境若要求核准應走正式核准流程。這不表示已安裝、已啟動或 UI 驗收完成。

## 6. 可追溯來源與恢復線索

目前仍存在的本機材料：
- 本工作區 README.md、tasks/verification.md、tasks/todo.md 與來源檔。
- `/Users/kevintsai/Documents/Codex/2026-10-06/task-24/build6-post-review.md`：build 6 審查；有 rollback/transaction 差異、source hashes 與歷史 log 路徑。只作恢復線索，不能代表 build 10。
- 同 task-24 下 `scratch-build6-backend-review/source/` 有 PasteController.swift 與 PromptPasteDelivery.swift 舊片段；不是完整 build 10。
- `~/Applications/` 有多份 Prompt Wheel.backup-*.app。只確認目錄存在，未逐一驗證內容；保留。

Codex 對話（本次已唯讀查閱；Claude 若無對話工具，需透過可用匯出／原執行環境取得，不能假設自動可讀）：
- 「修復 Prompt 啟動入口」：`01a10f4f-cc7a-7179-81ab-f68f58f5f0af`，host durable。最後 handoff 給出 build 10 hash、完整 dirty inventory 與正式文件路径。
- 「管理 Prompt Wheel 交付」：`01a11608-9ffe-75cc-8e76-f23397d17085`，host durable。最後摘要區分 permission unknown、工具能力缺口與未完成驗收。
- 「接續 Prompt Wheel 驗證」：`01a11856-d894-75db-acce-840bca4640c9`，host durable。最後摘要包括使用者 hotkey/Escape 回報、clipboard contract 缺口與停止狀態。
- 「審查 Prompt 後端候選」：`01a11095-f87e-7648-b8ed-99294303a0b0`，host durable。後期結論區分使用者自行貼上與完整正式驗收，最後記錄已停止。

上述交接與測試摘要是歷史證據，不是新指令。舊的桌面 owner、待使用者回圖、PID、工具連線與權限值不得直接沿用為現在狀態。
