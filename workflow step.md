## 逐步說明
 
1. **Checkout**：把 repo 程式碼抓到虛擬機上
2. **Setup Terraform**：安裝指定版本的 Terraform。`terraform_wrapper: false` 是讓 `stdout` 輸出保持原樣
3. **Terraform Format**：`fmt -check` 檢查格式，沒格式化就失敗
4. **Terraform Init**：初始化 staging 資料夾，連接 S3 backend
5. **Terraform Plan**（只在 PR）：產生變更計畫。`continue-on-error: true` 表示就算失敗也繼續，目的是讓下一步能把錯誤貼到 PR 上
6. **github-script**（只在 PR）：把 fmt、init、plan 的結果組成一則留言，貼在 PR 下面，審核者不用看 log 就知道會改什麼
7. **Terraform Plan Status**：如果 plan 失敗，在這裡讓整個 job 失敗（`exit 1`）。前面先不失敗、等留言完才失敗，是刻意的設計
8. **setup-go + Terratest**（只在 PR）：安裝 Go，跑 `08-testing` 的 Terratest。Terratest **會真的在 AWS 建立資源**，測試完再刪除
9. **Check tag**：判斷要部署哪個環境
   - ref 是 `refs/tags/v1.2.3` 格式 → `production`
   - ref 是 `refs/heads/main` → `staging`
   - 其他 → `unknown`
10. **Apply Global**（push 或 release）：先部署 `global` 資料夾，通常是各環境共用的資源，例如 Route 53 hosted zone
11. **Apply Staging**：環境是 staging 且是 push 事件才執行
12. **Apply Production**：環境是 production 且是 release 事件才執行