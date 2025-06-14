Write-Host "" -ForegroundColor White
Write-Host " Docker playground" -ForegroundColor Green
Write-Host "" -ForegroundColor White

$language = $args[0]
$action = $args[1]

switch ($action) {
    "build" {
        Write-Host "Building image..." -ForegroundColor Yellow
        Write-Host "" -ForegroundColor White
        docker-compose -f "$language/docker-compose.yml" build
    }
    "start" {
        Write-Host "Starting container..." -ForegroundColor Yellow
        docker-compose -f "$language/docker-compose.yml" up -d
    }
    "shell" {
        Write-Host "Entering container..." -ForegroundColor Yellow
        docker-compose -f "$language/docker-compose.yml" exec $language /bin/bash
    }
    "stop" {
        Write-Host "Stopping container..." -ForegroundColor Yellow
        docker-compose -f "$language/docker-compose.yml" down
    }
    "clean" {
        Write-Host "Cleaning up..." -ForegroundColor Yellow
        docker-compose -f "$language/docker-compose.yml" down -v --rmi all
    }
    "logs" {
        docker-compose -f "$language/docker-compose.yml" logs
    }
    default {
        Write-Host " Commands:" -ForegroundColor Yellow
        Write-Host "   .\run.ps1 <language> build" -ForegroundColor White
        Write-Host "   .\run.ps1 <language> start" -ForegroundColor White  
        Write-Host "   .\run.ps1 <language> shell" -ForegroundColor White
        Write-Host "   .\run.ps1 <language> stop" -ForegroundColor White  
        Write-Host "   .\run.ps1 <language> clean" -ForegroundColor White  
        Write-Host "   .\run.ps1 <language> logs" -ForegroundColor White
        Write-Host "" -ForegroundColor White
    }
}