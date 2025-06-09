
Write-Host "" -ForegroundColor White
Write-Host " Docker playground quickstart " -ForegroundColor Green
Write-Host "" -ForegroundColor White

$action = $args[0]

switch ($action) {
    "build" {
        Write-Host "Building image..." -ForegroundColor Yellow
        docker-compose build
    }
    "start" {
        Write-Host "Starting container..." -ForegroundColor Yellow
        docker-compose up -d
    }
    "shell" {
        Write-Host "Entering container..." -ForegroundColor Yellow
        docker-compose exec playground /bin/bash
    }
    "stop" {
        Write-Host "Stopping container..." -ForegroundColor Yellow
        docker-compose down
    }
    "clean" {
        Write-Host "Cleaning up..." -ForegroundColor Yellow
        docker-compose down -v --rmi all
    }
    "logs" {
        docker-compose logs -f playground
    }
    "backup" {
        Write-Host "Backing up volume..." -ForegroundColor Yellow
        docker run --rm -v docker-playground_playground-data:/data -v ${PWD}:/backup ubuntu tar czf /backup/playground-backup.tar.gz -C /data .
    }
    "restore" {
        Write-Host "Restoring from backup..." -ForegroundColor Yellow
        docker run --rm -v docker-playground_playground-data:/data -v ${PWD}:/backup ubuntu tar xzf /backup/playground-backup.tar.gz -C /data
    }
    default {
        Write-Host "   Commands:" -ForegroundColor Yellow
        Write-Host "     .\run.ps1 build" -ForegroundColor White
        Write-Host "     .\run.ps1 start" -ForegroundColor White  
        Write-Host "     .\run.ps1 shell" -ForegroundColor White
        Write-Host "     .\run.ps1 stop" -ForegroundColor White  
        Write-Host "     .\run.ps1 clean" -ForegroundColor White  
        Write-Host "     .\run.ps1 logs" -ForegroundColor White  
        Write-Host "     .\run.ps1 backup" -ForegroundColor White
        Write-Host "     .\run.ps1 restore" -ForegroundColor White
        Write-Host "" -ForegroundColor White
    }
}