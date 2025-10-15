# Upload marketing index.html to domain root
# This script safely deploys the SEO-optimized marketing page to futurelink.zip

param(
    [string]$BackupDate = (Get-Date -Format "yyyyMMdd"),
    [switch]$SkipBackup = $false
)

Write-Host "🚀 Deploying marketing page to futurelink.zip root..." -ForegroundColor Cyan
Write-Host "=" * 60

# Load environment variables
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
} else {
    Write-Host "❌ Error: .env file not found" -ForegroundColor Red
    exit 1
}

# Verify we have the root credentials
if (-not $static_host_name_root -or -not $static_host_user_name_root -or -not $static_host_password_root) {
    Write-Host "❌ Error: Missing root FTP credentials in .env" -ForegroundColor Red
    Write-Host "Required: static_host_name_root, static_host_user_name_root, static_host_password_root" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Credentials loaded:" -ForegroundColor Green
Write-Host "  Host: $static_host_name_root" -ForegroundColor Green
Write-Host "  User: $static_host_user_name_root" -ForegroundColor Green
Write-Host "  Pass: ***" -ForegroundColor Green

$marketingIndexPath = Join-Path (Get-Location) "marketing-root\index.html"

if (-not (Test-Path $marketingIndexPath)) {
    Write-Host "❌ Error: Marketing index.html not found at $marketingIndexPath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found marketing page: $marketingIndexPath" -ForegroundColor Green

# Backup existing index.html first (unless skipped)
if (-not $SkipBackup) {
    Write-Host "`n📋 Creating backup of existing root index.html..." -ForegroundColor Yellow
    try {
        $backupRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/index.html")
        $backupRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
        $backupRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
        $backupRequest.UsePassive = $true
        
        $backupResponse = $backupRequest.GetResponse()
        $backupStream = $backupResponse.GetResponseStream()
        $backupContent = New-Object byte[] $backupResponse.ContentLength
        $backupStream.Read($backupContent, 0, $backupResponse.ContentLength)
        
        $backupPath = "index-backup-$BackupDate.html"
        [System.IO.File]::WriteAllBytes($backupPath, $backupContent)
        
        $backupStream.Close()
        $backupResponse.Close()
        
        Write-Host "✅ Backup saved to: $backupPath" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Could not backup existing file (may not exist): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Upload the new marketing page
Write-Host "`n🚀 Uploading new marketing index.html to root..." -ForegroundColor Green

try {
    $ftpRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/index.html")
    $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $ftpRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
    $ftpRequest.UseBinary = $true
    $ftpRequest.UsePassive = $true
    
    $fileContent = [System.IO.File]::ReadAllBytes($marketingIndexPath)
    $ftpRequest.ContentLength = $fileContent.Length
    
    Write-Host "📦 File size: $($fileContent.Length) bytes" -ForegroundColor Cyan
    
    $requestStream = $ftpRequest.GetRequestStream()
    $requestStream.Write($fileContent, 0, $fileContent.Length)
    $requestStream.Close()
    
    $response = $ftpRequest.GetResponse()
    Write-Host "✅ Successfully uploaded marketing page!" -ForegroundColor Green
    Write-Host "🌐 Live at: https://futurelink.zip/" -ForegroundColor Cyan
    $response.Close()
    
    Write-Host "`n📋 Next steps:" -ForegroundColor Yellow
    Write-Host "1. Visit https://futurelink.zip/ to verify the new page loads" -ForegroundColor White
    Write-Host "2. Test that links to /family/ still work correctly" -ForegroundColor White
    Write-Host "3. Run SEO audit tools to confirm optimization" -ForegroundColor White
    
} catch {
    Write-Host "❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check your credentials and network connection." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n🎉 Marketing page deployment completed!" -ForegroundColor Green