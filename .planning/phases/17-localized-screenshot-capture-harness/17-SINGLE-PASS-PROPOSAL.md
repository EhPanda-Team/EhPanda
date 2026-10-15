<!-- Full historical proposal, preserved during the repository split. -->
This proposal records the state before `cea354a45e` and the resulting implementation. References to
direct commands inheriting retries describe the original problem, not the corrected documented
entry points. The ordinary UITests plan still retains its regression retry policy. Subsequent
appshot-specific consumer wiring is documented in [17-APPSHOT-INTEGRATION.md](17-APPSHOT-INTEGRATION.md).

# Phase 17 單次執行流程提案

本提案已獲本次執行授權。使用者說明這是選用 agent 的建議，不能據此阻止後續 agent 依新證據調整設計。執行結果另記於 `$HOME/Library/Caches/Appshot/handoff/STATUS.md`。

本次已獲執行授權，實作與驗證已完成，commit `cea354a45e`；原 test plan 保持不變。本提案只處理 Task A 列出的直接 UITests 命令，不移入 capture-cli 的變更。

## 現況

`Scripts/verify-full-content-capture.py` 的 `Gate.single_pass_run(plan)` 會從指定 DerivedData 的 `Build/Products` 找到唯一對應 test plan 的原始 xctestrun，移除所有巢狀 `TestRepetitionPolicy`，記錄移除內容，另存 `phase17-<plan>.xctestrun`。原始 xctestrun 與 UITests.xctestplan 保留。

`Gate.run` 以 `test-without-building`、該副本與明確 test selector 執行，關閉平行測試，並檢查預期測試數、全部通過、沒有 skip/expected failure/Repetition 節點及指定裝置。`Scripts/visual/capture-native.py` 已使用這條路徑。

直接 `xcodebuild test -testPlan UITests` 仍繼承 test plan 的 retryOnFailure，最多三次。移除誤用的命令列旗標已修正語法，但尚未使這些直接命令成為單次視覺證據。

## 建議範圍

1. 將 17-VALIDATION、17-RESEARCH 與 17-05、17-08、17-09、17-10、17-11 的受影響 UITests 命令，接到既有單次準備與驗證流程。保留每項原有 selector、裝置與實際預期測試數；先以建置／列舉證據確認數量，不自行猜測。
2. 沿用指定 DerivedData 的 build-for-testing 產物及 Gate，而不是另寫一份移除重試政策或結果判定邏輯。若現有入口不能表達某個 selector，僅擴充必要的參數入口。
3. 先用 generic simulator 目的地建置，再逐台、逐次執行 test-without-building；開始前等外來測試自行結束，保留完整命令、退出碼、日誌與 xcresult。
4. 對單次副本與結果驗證增加有意義的檢查：原始計畫未變，副本沒有 repetition policy，重複／跳過／零測試／數量錯誤均拒絕；實際選取的測試各執行一次。
5. 只在 Phase 17 分支另做獨立變更；先檢查其他工作新增的內容並避開未相關修改。這不包含更改 UITests.xctestplan 的一般回歸政策，也不包含執行完整視覺矩陣。

替代決定：維持直接命令作為一般回歸檢查，在所有受影響位置明示不能作為單次視覺驗收證據；嚴格視覺驗收繼續由既有 native runner 負責。

## 執行結果

196 個 Python 測試通過；iPhone、iPad 各執行一個指定測試，結果名稱、數量與列舉完全一致，沒有跳過或重複。原 test plan 保留。完整證據見 `$HOME/Library/Caches/Appshot/handoff/phase17-single-pass-verification.json`。各 producer 任務的完整場景驗收仍需另行執行。
