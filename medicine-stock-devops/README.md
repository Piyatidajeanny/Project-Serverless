# Medicine Stock DevOps Project
# 🚀 ระบบติดตามสต๊อกยาและวันหมดอายุ — ENG23 3074

> REST API สำหรับจัดการข้อมูลยา (สต๊อก, วันหมดอายุ, แจ้งเตือนใกล้หมด/สต๊อกต่ำ) พัฒนาด้วย Flask, เก็บ metric ด้วย Prometheus และเตรียม deploy บน Kubernetes

---

## 👥 สมาชิกในกลุ่ม

| รหัสนักศึกษา | ชื่อ-นามสกุล | ความรับผิดชอบ |
|------------|-------------|---------------|
| B6629298 | ปิยธิดา บัวบาน | App + Testing |
| B6612894 | ณัฐพงศ์ ทองเถาะ | Docker + CI/CD |
| B6639921 | ธนพัทธ์ พูนผล | Terraform + Kubernetes |
| B6610258 | สุรยุทธ หงษาวดี | Monitoring + Documentation |

หมายเหตุ: ตารางนี้เหลือเฉพาะชื่อ/รหัสสมาชิกให้กรอกก่อนส่งงาน

---

## 📌 ภาพรวมโปรเจกต์

### แอปพลิเคชัน
- ชื่อแอป: Medicine Stock API
- ประเภท: REST API
- ภาษา/Framework: Python 3.11 + Flask
- ฐานข้อมูล: SQLite (ไฟล์ `medicine.db`)

### ความสามารถหลัก
1. จัดการข้อมูลยาแบบ CRUD
2. ค้นหารายการยาใกล้หมดอายุ (default 180 วัน)
3. ค้นหารายการยาสต๊อกต่ำ (quantity <= min_stock)
4. เปิด endpoint `/metrics` สำหรับ Prometheus

### Architecture Diagram
```text
Developer
    |
    | push code
    v
GitHub -> Jenkins (planned)
                      |
                      v
          Build/Test/Docker Push
                      |
                      v
             Kubernetes Cluster
          (namespace: medicine-stock)
                      |
                      v
         Service NodePort: 30081
                      |
                      v
                Prometheus
                      |
                      v
                  Grafana
```

---

## 📁 โครงสร้าง Repository

```text
medicine-stock-devops/
|-- app/
|   |-- app.py
|   |-- requirements.txt
|   |-- seed_data.py
|   |-- test_app.py
|   `-- data/medicine_dataset.json
|-- Dockerfile
|-- Jenkinsfile
|-- terraform/
|   |-- main.tf
|   |-- variables.tf
|   `-- outputs.tf
|-- ansible/
|   |-- inventory
|   `-- playbook.yml
|-- k8s/
|   |-- deployment.yaml
|   `-- service.yaml
|-- monitoring/
|   |-- prometheus.yml
|   `-- grafana-dashboard.json
`-- README.md
```

---

## ⚙️ Prerequisites

| Tool | Version ที่แนะนำ | ใช้ทำอะไร |
|------|------------------|------------|
| Python | 3.11+ | รัน Flask API และ test |
| pip | ล่าสุด | ติดตั้ง dependencies |
| Docker | 24+ | build/run container |
| kubectl | 1.28+ | deploy Kubernetes manifests |
| Kubernetes (Minikube/K3s/Kind) | ล่าสุด | รันแอปในคลัสเตอร์ |
| Terraform | 1.0+ | สร้าง namespace ใน Kubernetes |
| Prometheus | 2.x+ | scrape metrics |
| Grafana | 10.x+ | ทำ dashboard monitoring |

---

## 🏃 Quick Start

### 1) รันแบบ Local
```bash
cd medicine-stock-devops/app
python -m venv .venv

# Windows PowerShell
. .venv/Scripts/Activate.ps1

# macOS/Linux
# source .venv/bin/activate

pip install -r requirements.txt
python app.py
```

API จะรันที่ `http://localhost:5000`

### 2) Seed ข้อมูลตัวอย่าง
```bash
cd medicine-stock-devops/app
python seed_data.py
```

ชุดข้อมูลตัวอย่างใน `app/data/medicine_dataset.json` มี 10 รายการ

### 3) รัน Unit Test
```bash
cd medicine-stock-devops/app
pytest -v
```

### 4) รันผ่าน Docker
```bash
cd medicine-stock-devops
docker build -t medicine-stock-api:latest .
docker run --rm -p 5000:5000 medicine-stock-api:latest
```

---

## 🧪 API Endpoints

Base URL: `http://localhost:5000`

| Method | Endpoint | รายละเอียด |
|-------|----------|-------------|
| GET | `/` | Health check |
| GET | `/drugs` | ดึงรายการยาทั้งหมด |
| POST | `/drugs` | เพิ่มข้อมูลยาใหม่ |
| PUT | `/drugs/<id>` | แก้ไขข้อมูลยาตาม id |
| DELETE | `/drugs/<id>` | ลบข้อมูลยาตาม id |
| GET | `/drugs/expiring-soon?days=180` | ดูรายการยาใกล้หมดอายุ |
| GET | `/drugs/low-stock` | ดูรายการยาสต๊อกต่ำ |
| GET | `/metrics` | Prometheus metrics |

ตัวอย่าง payload สำหรับ POST `/drugs`

```json
{
  "drug_name": "Paracetamol 500 mg",
  "category": "Analgesic",
  "lot_number": "PCM011",
  "quantity": 100,
  "min_stock": 30,
  "expiry_date": "2027-12-31"
}
```

---

## 📊 Monitoring

### Prometheus
- Config: `monitoring/prometheus.yml`
- Scrape interval: 15 วินาที
- Target ปัจจุบัน: `host.docker.internal:30081`

รัน Prometheus:
```bash
prometheus --config.file=monitoring/prometheus.yml
```

Prometheus UI: `http://localhost:9090`

### Metrics สำคัญจากแอป
- `http_requests_total`
- `http_request_duration_seconds`
- `drug_total`
- `expiring_drug_total`
- `low_stock_drug_total`
- `medicine_stock_quantity`
- `medicine_days_to_expiry`
- `medicine_low_stock_status`
- `medicine_expiring_status`

### Grafana
หมายเหตุสถานะไฟล์ dashboard:
1. `monitoring/grafana-dashboard.json` ยังเป็นไฟล์ว่าง
2. มีไฟล์ dashboard ที่ใช้งานได้อยู่ที่ root ชื่อ `gafana-dashboard.json` (สะกดตามไฟล์จริง)

วิธี import dashboard:
1. เปิด Grafana ที่ `http://localhost:3000`
2. ไปที่ Dashboards -> Import
3. อัปโหลดไฟล์ `gafana-dashboard.json`

---

## ☸️ Kubernetes Deployment

ค่า deploy ที่กำหนดไว้แล้ว:
1. Namespace: `medicine-stock`
2. Deployment: `medicine-stock-api`
3. Replicas: 2
4. Container image: `piyatida26/medicine-stock-api:latest`
5. Service: NodePort `30081` (port 5000 -> targetPort 5000)

### Deploy
```bash
kubectl create namespace medicine-stock
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### ตรวจสอบสถานะ
```bash
kubectl get pods -n medicine-stock
kubectl get svc -n medicine-stock
```

เข้าใช้งาน API ผ่าน NodePort:
```text
http://localhost:30081
```

---

## 🏗️ Infrastructure as Code

### Terraform
โค้ด Terraform ในโปรเจกต์นี้สร้าง Kubernetes namespace ตามตัวแปร `namespace` (default = `medicine-stock`)

```bash
cd medicine-stock-devops/terraform
terraform init
terraform plan
terraform apply
```

### Ansible
โฟลเดอร์ `ansible/` มีไฟล์ `inventory` และ `playbook.yml` แต่เนื้อหายังว่าง (ยังไม่ implement task)

---

## 🔄 CI/CD Pipeline (Jenkins)

สถานะปัจจุบัน: มีไฟล์ `Jenkinsfile` แล้ว แต่ยังว่าง (pipeline ยังไม่ถูกกำหนดขั้นตอน)

ตัวอย่าง flow ที่แนะนำ:
```text
Checkout -> Install deps -> Test -> Docker Build -> Push Image -> kubectl apply
```

---

## 🌿 Branching Strategy (แนะนำ)

```text
main      : production-ready
develop   : รวมงานก่อนขึ้น main
feature/* : งานรายฟีเจอร์
```

---

## 🐛 Troubleshooting

### 1) เรียก `/metrics` ไม่ได้
```bash
curl http://localhost:5000/metrics
```
ถ้ารันบน Kubernetes ให้เช็ก service/pod และพอร์ต 30081

### 2) Pod ดึง image ไม่ได้
```bash
kubectl describe pod <pod-name> -n medicine-stock
```
ดู Event ว่าเกิดจาก ImagePullBackOff หรือชื่อ image ไม่ถูกต้อง

### 3) Test ล้มเหลว
ให้รันในโฟลเดอร์ `app` และติดตั้ง dependency ก่อน
```bash
pip install -r requirements.txt
pytest -v
```

---

## 📚 References

- Flask: https://flask.palletsprojects.com/
- Prometheus Python Client: https://github.com/prometheus/client_python
- Terraform: https://developer.hashicorp.com/terraform/docs
- Kubernetes: https://kubernetes.io/docs/
- Grafana: https://grafana.com/docs/

