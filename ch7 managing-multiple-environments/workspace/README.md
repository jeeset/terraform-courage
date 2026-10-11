- 建立一個名為 production 的新 workspace，並自動切換過去
```
terraform workspace new production
```
- 列出所有 workspace，目前所在的會標 `*`
```
terraform workspace list
```
- 切換到 staging 這個 workspace
```
terraform workspace select staging
```