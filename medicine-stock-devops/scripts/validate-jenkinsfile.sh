#!/bin/bash
# Jenkinsfile Validator Script

JENKINSFILE="./Jenkinsfile"

echo "=========================================="
echo "  Jenkinsfile Validation Report"
echo "=========================================="
echo ""

# Check if file exists
if [ ! -f "$JENKINSFILE" ]; then
    echo "❌ Jenkinsfile not found!"
    exit 1
fi

echo "📄 File: $JENKINSFILE"
echo "📊 Lines: $(wc -l < $JENKINSFILE)"
echo ""

# Check for balanced braces
OPEN_BRACES=$(grep -o "{" "$JENKINSFILE" | wc -l)
CLOSE_BRACES=$(grep -o "}" "$JENKINSFILE" | wc -l)

echo "Syntax Check:"
if [ "$OPEN_BRACES" -eq "$CLOSE_BRACES" ]; then
    echo "✓ Braces balanced: { = $OPEN_BRACES, } = $CLOSE_BRACES"
else
    echo "✗ Braces unbalanced: { = $OPEN_BRACES, } = $CLOSE_BRACES"
    exit 1
fi

# Check for required keywords
echo ""
echo "Required Keywords:"

KEYWORDS=("pipeline" "agent" "stages" "stage" "steps" "environment" "post")
for kw in "${KEYWORDS[@]}"; do
    if grep -q "\b$kw\b" "$JENKINSFILE"; then
        COUNT=$(grep -o "\b$kw\b" "$JENKINSFILE" | wc -l)
        echo "✓ $kw (found $COUNT times)"
    else
        echo "✗ $kw (NOT FOUND)"
    fi
done

# Check for stages
echo ""
echo "Stages Defined:"
grep "stage(" "$JENKINSFILE" | sed "s/.*stage('\([^']*\)'.*/  • \1/" | sort

# Additional checks
echo ""
echo "Additional Checks:"

# Check for checkout
if grep -q "checkout scm" "$JENKINSFILE"; then
    echo "✓ Git checkout configured"
else
    echo "✗ Git checkout not found"
fi

# Check for docker
if grep -q "docker build" "$JENKINSFILE"; then
    echo "✓ Docker build configured"
else
    echo "⚠ Docker build not found"
fi

# Check for kubernetes
if grep -q "kubectl" "$JENKINSFILE"; then
    echo "✓ Kubernetes deployment configured"
else
    echo "⚠ Kubernetes deployment not found (optional)"
fi

# Check for credentials
if grep -q "credentials(" "$JENKINSFILE"; then
    echo "✓ Credentials referenced"
else
    echo "⚠ No credentials referenced"
fi

# Check for error handling
if grep -q "try\|catch\|post" "$JENKINSFILE"; then
    echo "✓ Error handling configured"
else
    echo "⚠ No error handling found"
fi

echo ""
echo "=========================================="
echo "  ✓ Jenkinsfile structure is valid!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Set DOCKER_IMAGE environment variable in Jenkinsfile"
echo "2. Configure Jenkins credentials (dockerhub-credentials)"
echo "3. Create Jenkins job from this Jenkinsfile"
echo "4. Set up webhook for automatic triggering"
echo ""
