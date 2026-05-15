# Test Docker container
docker run -d --name medicine-stock-test -p 5001:5000 -e DB_PATH=/app/medicine.db medicine-stock:latest
Start-Sleep -Seconds 3
docker logs medicine-stock-test
$result = docker ps | findstr medicine-stock-test
Write-Output "Container running: $result"
