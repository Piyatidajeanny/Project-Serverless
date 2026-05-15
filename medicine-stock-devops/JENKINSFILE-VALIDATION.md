# Jenkinsfile Validation Methods

## วิธีที่ 1: Jenkins Declarative Linter API (Recommended)
ถ้า Jenkins ติด ที่ localhost:8080:

```bash
curl -X POST -F "jenkinsfile=@Jenkinsfile" \
  http://localhost:8080/pipeline-model-converter/validate
```

บน Windows PowerShell:
```powershell
$jenkinsfileContent = Get-Content -Path Jenkinsfile -Raw
$uri = "http://localhost:8080/pipeline-model-converter/validate"
$form = @{ jenkinsfile = $jenkinsfileContent }
Invoke-RestMethod -Uri $uri -Method Post -Form $form
```

## วิธีที่ 2: Online Jenkins Validator
- https://www.jenkins.io/doc/book/pipeline/declarative/
- https://declarative-pipeline-validator.herokuapp.com/

Copy-paste Jenkinsfile content แล้ว Validate

## วิธีที่ 3: Jenkins CLI
```bash
# Download jenkins-cli.jar
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

# Validate Jenkinsfile
java -jar jenkins-cli.jar -s http://localhost:8080 \
     declarative-linter < Jenkinsfile
```

## วิธีที่ 4: Groovy Syntax Check
```bash
# macOS: brew install groovy
# Linux: apt-get install groovy
# Windows: choco install groovy

groovy -c Jenkinsfile
```

## วิธีที่ 5: Docker Groovy Validator
```bash
docker run --rm -v $(pwd):/workspace -w /workspace \
  groovy:latest groovy -c Jenkinsfile
```

## วิธีที่ 6: IDE Extensions
- VS Code: "Groovy Lint" extension
- IntelliJ IDEA: built-in Groovy support
- vim/neovim: groovy syntax plugin

## วิธีที่ 7: GitHub Actions
Create `.github/workflows/validate-jenkinsfile.yml`:

```yaml
name: Validate Jenkinsfile
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate Jenkinsfile
        run: |
          docker run --rm -v $(pwd):/workspace -w /workspace \
            groovy:latest groovy -c Jenkinsfile
```

## วิธีที่ 8: Simple Syntax Check (Basic)
```bash
# Check for basic groovy syntax errors
grep -E "^\s*(stage|pipeline|steps|agent)" Jenkinsfile | head -20

# Check for unmatched braces
grep -o "{" Jenkinsfile | wc -l  # Count {
grep -o "}" Jenkinsfile | wc -l  # Count }
# They should be equal
```

---

## ⚡ Quick Validation Checklist

- [ ] `pipeline { ... }` wrapper exists
- [ ] `agent any` or specific agent defined
- [ ] Stages inside `stages { ... }`
- [ ] Each stage has a `name` and `steps`
- [ ] Braces are balanced `{ ... }`
- [ ] No syntax errors in environment/parameters
- [ ] Credentials IDs exist in Jenkins
- [ ] Docker image names are valid
- [ ] Kubernetes namespace exists

---

## 🔍 Our Jenkinsfile Structure

```
pipeline {
    agent any
    
    environment { ... }        ✓
    parameters { ... }         ✓
    options { ... }            ✓
    
    stages {
        stage('1. Checkout & Setup') { ... }    ✓
        stage('2. Unit Test') { ... }           ✓
        stage('3. Build Docker Image') { ... }  ✓
        stage('4. Security Scan') { ... }       ✓
        stage('5. Push to Registry') { ... }    ✓
        stage('6. Deploy to K8s') { ... }       ✓
    }
    
    post {
        always { ... }         ✓
        success { ... }        ✓
        failure { ... }        ✓
        unstable { ... }       ✓
    }
}
```

All elements are properly structured! ✅
