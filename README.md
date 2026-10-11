## 什麼是Terraform?
可以寫配置文件去建立、管理雲平台的基礎設施
[Terraform Registry](https://registry.terraform.io/)
## 基本架構
![image](https://hackmd.io/_uploads/rJtRvXvszl.png)

## 基本指令
- 初始化工作目錄
```
$ terraform init
```
- 預覽會發生什麼變更
```
$ terraform plan
```

- 實際變更執行
```
# terraform apply
```
- 刪除所有資源
```
$ terraform destroy
```

## state file
==terraform.tfstate==
它是 Terraform 的記憶，記錄「我建立過哪些資源、它們在 AWS 上的真實 ID 和屬性是什麼」。
:::danger
state file 內容包含敏感資料(帳號密碼等.....)，故要注意
:::

## Backend
Terraform 用來存放 `state` 檔的地方。

- Local backend（預設）
state 就存在你電腦的專案資料夾裡

問題是：

    - 只有你的電腦有，同事無法協作
    - 電腦壞了或誤刪，Terraform 就「忘記」建過哪些資源
    - 兩個人同時 apply 沒有鎖，可能把 state 弄壞
    - state 裡可能有密碼等敏感資料，以明文存在本機

- Remote backend
把 state 存到遠端共用的地方。在 AWS 上最常見的就是 S3

好處：

    - 團隊共用：大家讀寫同一份 state
    - lock：use_lockfile 在 S3 放一個 .tflock 檔，防止同時 apply
    - 備份與還原：bucket 開啟 versioning，state 被改壞可以回到舊版本
    - 加密與權限：用 S3 加密和 IAM 控制誰能讀寫 state

## 多環境管理
兩種方法:
1. Workspaces
同一份程式碼、同一個 backend，用 workspace 切出多份獨立的 state

    `優點`:
    - 容易上手
    - terraform.workspace 表達式：程式碼裡可以直接拿到目前環境名稱，用來命名資源或調整規格
    - 減少重複程式碼

    `缺點`:
    - 容易人為失誤
    - 所有環境的state 存在同一個 backend:代表能存取 dev state 的人，通常也能存取 production state，無法做到權限隔離。
    - 程式碼看不出部署了什麼
    

2. File Structure（目錄結構 + modules）
每個環境一個資料夾，共用的邏輯抽成 module

    `優點`:
    - backend 隔離：每個環境資料夾有自己的 backend 設定，可以放在不同的 bucket，甚至不同的 AWS 帳號
    - 安全性提升：可以用 IAM 限制只有特定人能存取 production 的 bucket 和帳號，dev 的權限碰不到 production。
    - 降低人為失誤：要操作 production 必須明確 cd production/，路徑本身就提醒你在哪個環境，不像 workspace 是看不到的隱藏狀態
    - 程式碼完整反映部署狀態：打開資料夾就知道有哪些環境，terraform.tfvars 裡直接寫著每個環境的參數，例如 production 用 t3.large、dev 用 t3.micro，不需要去猜條件判斷。

    `缺點`:
    - 要執行多次 apply：每個環境是獨立的 root module，要分別進去執行
    - 程式碼較重複，但可以用 module 減少：各環境的 main.tf 都要寫 backend、provider 和 module 呼叫。把實際資源邏輯放進 _modules/，環境資料夾就只剩很薄的一層「呼叫 module + 傳參數」，重複的部分就很少了。
    

## Terragrunt
Terragrunt 是 Gruntwork 開發的一個 Terraform（和 OpenTofu）包裝工具。它不取代 Terraform，而是在外面多加一層，專門解決剛才「檔案結構」做法的缺點：重複的程式碼和要分別執行多次 apply。