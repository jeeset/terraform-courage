# 假設 S3 bucket 未建，請先apply一次 ch3/aws-backend/main.tf
terraform { 
  backend "s3" {
    bucket         = "terraform-state-jeeset-pra"
    key            = "tf-infra/terraform.tfstate"
    region         = "ap-east-2"
    encrypt        = true
  }
  # 要用甚麼provider
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# 定義默認區域
provider "aws" {
  region = "ap-east-2"
}

# 自動查詢該區域最新的 Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# 建立instance1
resource "aws_instance" "instance_1" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.instances.name]
  user_data       = <<-EOF
              #!/bin/bash
              echo "Hello, World 1" > index.html
              python3 -m http.server 8080 &
              EOF
}

# 建立instance2
resource "aws_instance" "instance_2" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.instances.name]
  user_data       = <<-EOF
              #!/bin/bash
              echo "Hello, World 2" > index.html
              python3 -m http.server 8080 &
              EOF
}

# 查詢這個區域的預設 VPC
data "aws_vpc" "default_vpc" {
  default = true
}

# 查詢預設 VPC 裡的所有子網路
data "aws_subnets" "default_subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

# 建立 instance 用的 security group
resource "aws_security_group" "instances" {
  name = "instance-security-group"
}

# 寫 security group 的 rule
resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id

  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# 建立負載平衡器的監聽器，負責「在哪個 port 等待連線、收到請求後要怎麼處理」
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn

  port = 80

  protocol = "HTTP"

  # 當請求不符合任何規則時要怎麼處理
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain" # 回傳純文字
      message_body = "404: page not found" # 回傳的內容
      status_code  = 404 # HTTP 狀態碼：找不到頁面
    }
  }
}

# 定義負載平衡器要把流量轉給誰、用什麼port、怎麼確認對方還活著
resource "aws_lb_target_group" "instances" {
  name     = "example-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 將 instance1 加入 target group
resource "aws_lb_target_group_attachment" "instance_1" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.instance_1.id
  port             = 8080
}

# 將 instance2 加入 target group
resource "aws_lb_target_group_attachment" "instance_2" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.instance_2.id
  port             = 8080
}

# 建立負載平衡器的監聽規則
resource "aws_lb_listener_rule" "instances" {
  listener_arn = aws_lb_listener.http.arn

  # 優先順序：數字越小越先比對，範圍 1～50000
  # 有多條規則時，會從小到大逐一檢查，符合第一條就執行，不再往下比
  priority     = 100
  # 什麼樣的請求符合這條規則
  condition {
    path_pattern {
      values = ["*"] # * 代表任何路徑都符合，例如 /、/about、/api/xxx 全部算
    }
  }
  # 符合條件後要做什麼
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }
}

# 建立負載平衡器用的 security_group
resource "aws_security_group" "alb" {
  name = "alb-security-group"
}

# 允許外面的人用 HTTP 連進負載平衡器
resource "aws_security_group_rule" "allow_alb_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# 允許負載平衡器把流量送出去
resource "aws_security_group_rule" "allow_alb_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

# 建立負載平衡器
resource "aws_lb" "load_balancer" {
  name               = "web-app-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default_subnet.ids
  security_groups    = [aws_security_group.alb.id]
}

# AWS Route 53 建立一個Hosted Zone(不會幫你註冊網域)
resource "aws_route53_zone" "primary" {
  name = "devopsdeployed.com" # 要管理的網域名稱
}

# 在託管區域裡新增一筆 DNS 紀錄，把網域指向負載平衡器
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id # 加在哪個託管區域
  name    = "devopsdeployed.com" # 紀錄名稱，這裡是根網域（不含 www）
  type    = "A" # A 紀錄：網域 → IP 位址

  # 別名（alias）：AWS 特有功能，直接指向 AWS 資源，而不是寫死 IP
  alias {
    name                   = aws_lb.load_balancer.dns_name # 負載平衡器的 DNS 名稱
    zone_id                = aws_lb.load_balancer.zone_id # 負載平衡器所屬的託管區域 ID（AWS 規定要填
    evaluate_target_health = true # 負載平衡器不健康時，DNS 不回應這筆紀錄
  }
}

/* 
# 建立一個 RDS 資料庫（AWS 託管的資料庫服務）
resource "aws_db_instance" "db_instance" {
  allocated_storage = 20 # 儲存空間 20 GB
  # 允許 AWS 在主版本內自動升級次版本（例如 12.1 → 12.5）
  # 但 AWS 可能在你沒注意時自動升級，正式環境可能太冒險
  auto_minor_version_upgrade = true

  storage_type        = "standard" # 儲存類型
  engine              = "postgres"     # 資料庫引擎：PostgreSQL
  engine_version      = "12"           # 主版本號
  instance_class      = "db.t2.micro"  # 機器規格
  name                = "mydb"         # 建立時自動產生的資料庫名稱
  username            = "foo"          # 管理員帳號
  password            = "foobarbaz"    # 管理員密碼
  skip_final_snapshot = true           # 刪除時不留最後備份（練習用，正式環境不要這樣）
}
*/