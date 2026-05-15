# Medicine Stock DevOps — การตั้งค่า CI/CD Pipeline

## 📋 ภาพรวม

เอกสารนี้อธิบาย CI/CD pipeline ที่สมบูรณ์สำหรับโครงการ Medicine Stock รวมถึง:
- **Jenkins Pipeline** (6 stages: Build, Test, Security Scan, Push, Deploy)
- **Docker** multi-stage build ที่มี health checks
- **Docker Compose** สำหรับการพัฒนาในเครื่อง
- **Kubernetes** deployment manifests
- **Webhook** automation สำหรับ GitHub/GitLab

---

## 🏗️ สถาปัตยกรรม

```
Git Repository (GitHub/GitLab)
        ↓
   [Webhook Trigger]
        ↓
   Jenkins Pipeline
   ├─ Stage 1: Checkout & Setup
   ├─ Stage 2: Unit Test (pytest)
   ├─ Stage 3: Build Docker Image
   ├─ Stage 4: Security Scan (Trivy)
   ├─ Stage 5: Push to Docker Registry
   └─ Stage 6: Deploy to Kubernetes
        ↓
Docker Hub / Private Registry
        ↓
Kubernetes Cluster
```

---

## 🐳 การตั้งค่า Docker

### สร้างในเครื่อง

```bash
# สร้าง image
docker build -t medicine-stock:latest .

# ทดสอบ image
docker run -p 5000:5000 -e DB_PATH=/app/medicine.db medicine-stock:latest
```

### ใช้ Docker Compose

```bash
# เริ่มบริการทั้งหมด (App, Prometheus, Grafana)
docker-compose up -d

# ดูบันทึก
docker-compose logs -f app

# หยุดบริการ
docker-compose down
```

**บริการ:**
- **App**: http://localhost:5000
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)

---

## 🚀 ขั้นตอน Jenkinsfile

### Stage 1: Checkout & Setup
- Clone repository
- แสดงข้อมูล branch

### Stage 2: Unit Test
- รัน pytest บน `app/test_app.py`
- สร้าง JUnit XML report
- เผยแพร่ผลการทดสอบ

### Stage 3: Build Docker Image
- สร้าง multi-stage Dockerfile
- Tag เป็น `medicine-stock:${BUILD_NUMBER}` และ `medicine-stock:latest`

### Stage 4: Security Scan
- รัน Trivy container image scan (ตัวเลือก)
- ตรวจสอบจุดอ่อน critical/high

### Stage 5: Push to Docker Registry
- เข้าสู่ Docker Hub
- Push image tags
- เงื่อนไข: ถ้า `PUSH_TO_REGISTRY=true` เท่านั้น

### Stage 6: Deploy to Kubernetes
- อัปเดต deployment image tag
- ประยุกต์ service manifests
- รอ rollout (timeout 5 นาที)
- เงื่อนไข: ถ้า `DEPLOY_K8S=true` เท่านั้น

---

## 🔧 สคริปต์ CI/CD

### Unix/Linux/macOS

```bash
# ทำให้สามารถรันได้
chmod +x scripts/ci-pipeline.sh

# สร้าง image
./scripts/ci-pipeline.sh build

# รันการทดสอบ
./scripts/ci-pipeline.sh test

# ทดสอบ image
./scripts/ci-pipeline.sh test-image

# Push ไปยัง registry
./scripts/ci-pipeline.sh push

# ปล่อยไปยัง K8s
./scripts/ci-pipeline.sh deploy

# รันทั้งหมด (test → build → test image)
./scripts/ci-pipeline.sh all
```

### Windows

```batch
# สร้าง image
scripts\ci-pipeline.bat build

# รันการทดสอบ
scripts\ci-pipeline.bat test

# ทดสอบ image
scripts\ci-pipeline.bat test-image

# ขั้นตอนทั้งหมด
scripts\ci-pipeline.bat all
```

---

## 🔌 การตั้งค่า Webhook

### GitHub

1. ไปที่ **Repository Settings** → **Webhooks** → **Add webhook**
2. **Payload URL**: `https://your-domain.com:5555/github-webhook`
3. **Secret**: ตั้งค่าเป็น `WEBHOOK_SECRET` environment variable
4. **Events**: เลือก "Push events" และ "Pull requests"
5. **Active**: ✓ ตรวจสอบ

### GitLab

1. ไปที่ **Settings** → **Integrations** → **Webhooks**
2. **URL**: `https://your-domain.com:5555/gitlab-webhook`
3. **Token**: ตั้งค่าเป็น `WEBHOOK_SECRET` environment variable
4. **Trigger**: Push events, Merge requests
5. **SSL verification**: เปิด/ปิดตามต้องการ

### ปล่อย Webhook Receiver

```bash
# ติดตั้ง dependencies
pip install flask requests

# ตั้งค่า environment variables
export JENKINS_URL=http://localhost:8080
export JENKINS_JOB=medicine-stock-pipeline
export JENKINS_TOKEN=your-jenkins-token
export WEBHOOK_SECRET=your-secret
export WEBHOOK_PORT=5555

# รัน webhook receiver
python scripts/webhook-receiver.py
```

หรือใช้ Docker:

```bash
docker run -d \
  -e JENKINS_URL=http://jenkins:8080 \
  -e JENKINS_JOB=medicine-stock-pipeline \
  -e JENKINS_TOKEN=your-token \
  -e WEBHOOK_SECRET=your-secret \
  -p 5555:5555 \
  -v $(pwd)/scripts/webhook-receiver.py:/app/webhook-receiver.py \
  python:3.11 \
  python /app/webhook-receiver.py
```

---

## 📦 Docker Hub Configuration

### Create Repository

1. Login to [Docker Hub](https://hub.docker.com)
2. Click **Create Repository**
   - **Name**: `medicine-stock`
   - **Visibility**: Private (recommended)
3. Click **Create**

### Jenkins Docker Credentials

1. Jenkins Dashboard → **Manage Jenkins** → **Manage Credentials**
2. Click **New credentials**
   - **Kind**: Username with password
   - **Username**: Your Docker Hub username
   - **Password**: Your Docker Hub token (generate at account settings)
   - **ID**: `dockerhub-credentials`
3. Click **Create**

### Update Jenkinsfile

Replace `your-dockerhub-username`:

```groovy
DOCKER_IMAGE = "your-dockerhub-username/medicine-stock"
```

---

## ☸️ Kubernetes Deployment

### Prerequisites

```bash
# Check kubectl
kubectl cluster-info

# Create namespace (optional)
kubectl create namespace medicine-stock

# Create secret for Docker registry (if private)
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=your-username \
  --docker-password=your-password \
  -n medicine-stock
```

### Deployment Manifests

Files are in `k8s/`:
- `deployment.yaml` - Flask app deployment
- `service.yaml` - NodePort/LoadBalancer service

### Deploy Manually

```bash
# Apply manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Check status
kubectl get pods -l app=medicine-stock
kubectl get svc medicine-stock-service

# View logs
kubectl logs -f deployment/medicine-stock
```

### Access Application

```bash
# Get service endpoint
kubectl get svc medicine-stock-service

# Port forward (local testing)
kubectl port-forward svc/medicine-stock-service 5000:5000
# Visit http://localhost:5000
```

---

## ✅ ทดสอบ Pipeline

### 1. ทดสอบผลลาง

```bash
# รันการทดสอบคนหลัก
cd app
python -m pytest test_app.py -v

# สร้างและทดสอบ image
docker build -t medicine-stock:test .
docker run --rm -p 5000:5000 medicine-stock:test &
sleep 2
curl http://localhost:5000/
```

### 2. Jenkins Job ทดสอบ

1. ไปที่ Jenkins Dashboard
2. คลิก **New Item** → **Pipeline**
3. **Name**: `medicine-stock-pipeline`
4. **Pipeline** → **Definition**: Pipeline script from SCM
5. **SCM**: Git
6. **Repository URL**: URL ริโปโหรงเณืองของคุณ
7. **Script Path**: `Jenkinsfile`
8. คลิก **Save** → **Build Now**

### 3. Webhook ทดสอบ

```bash
# ทดสอบ GitHub webhook คนหลัก
curl -X POST http://localhost:5555/github-webhook \
  -H "X-GitHub-Event: push" \
  -H "X-Hub-Signature-256: sha256=abc123" \
  -H "Content-Type: application/json" \
  -d '{"ref":"refs/heads/main","after":"abc123"}'
```

---

## 🔐 ปงกานครอบ (คู่ตั่ง
)

1. **Credentials**: ใช้ Jenkins credential store ไม่ทำให้แสดง
2. **Secrets**: เก็บไว้ใน environment variables หรือ CI/CD secrets
3. **RBAC**: จำกัดสิทธิ์ Kubernetes service account
4. **Image Scan**: เปิดการสแกน Trivy ใน pipeline
5. **Registry**: ใช้ private Docker registry
6. **Webhook Secret**: ตั้งค่าและตรวจสอบ webhook signatures

---

## 📊 การติดตามผล

### Prometheus Metrics

- `drug_total` - ยาแล์ทั้งหมด
- `medicine_stock_quantity` - หมวดต่อ ยาแล์
- `medicine_expiring_status` - ยาแล์กำลังหมดอายุ
- `http_requests_total` - คำรอส API

### Grafana Dashboard

- นำเข้า `gafana-dashboard.json` ไปที่ Grafana
- ดู metrics แบบผลผลีริภูมิ
- ตั้งค่า alerts

---

## 🛠️ การแก้ไขปัญหา

### Docker build ล้มเหลว
```bash
# ลบคืะ cache และลอง
docker build --no-cache -t medicine-stock:latest .
```

### Kubernetes pod ไม่เริ่มต้น
```bash
# ตรวจสอบเหตุการณ์ pod
kubectl describe pod medicine-stock-xxx

# ดูบันทึก
kubectl logs medicine-stock-xxx

# ตรวจสอบ resource limits
kubectl top pod
```

### Jenkins ไม่สามารถเชื่อมต่อ Docker
```bash
# ตรวจสอบสิทธิ Docker socket
sudo usermod -aG docker jenkins

# เริ่มต้อม Jenkins ใหม่
sudo systemctl restart jenkins
```

### Webhook ไม่ trigger
1. ตรวจสอบว่า webhook secret ถูกต้อง
2. ดู Jenkins logs: `docker logs jenkins`
3. ทดสอบ webhook endpoint: `curl http://your-domain:5555/health`

---

## 📚 อ้างอิง

- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Prometheus Metrics](https://prometheus.io/docs/concepts/data_model/)

---

## 📝 การบำรุงรักษา

### อัปเดต Dependencies
```bash
# อัปเดต app requirements
pip freeze > app/requirements.txt

# Commit และ push - webhook auto-triggers build
git add app/requirements.txt
git commit -m "chore: update dependencies"
git push origin main
```

### ทำความสะอาด Docker Resources
```bash
# ลบ images ที่ไม่ใช้
docker image prune -f

# ลบ volumes ที่ไม่ได้ใช้
docker volume prune -f
```

---

**อัปเดตล่าสุด**: 2026-05-14  
**เวอร์ชัน**: 1.0.0
