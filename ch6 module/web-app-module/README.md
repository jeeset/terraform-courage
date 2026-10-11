==正式環境要模組化，後續方便維護及利用==

| 檔案 | 內容 |
|---|---|
| `compute.tf` | EC2 |
| `database.tf` | RDS |
| `dns.tf` | Route 53 |
| `networking.tf` | VPC、子網路、安全群組、負載平衡器 |
| `storage.tf` | S3 |
| `main.tf` | 共用的東西，可能是 `terraform` 區塊或 provider |