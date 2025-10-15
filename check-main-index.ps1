# Check the main public_html index.php that might be controlling routing

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🔍 Checking main public_html/index.php..." -ForegroundColor Cyan

try {
    Write-Host "`n📥 Downloading public_html/index.php..." -ForegroundColor Yellow
    $downloadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/public_html/index.php")
    $downloadRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $downloadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
    $downloadRequest.UsePassive = $true
    
    $downloadResponse = $downloadRequest.GetResponse()
    $downloadStream = $downloadResponse.GetResponseStream()
    
    $localFile = New-Object byte[] $downloadResponse.ContentLength
    $downloadStream.Read($localFile, 0, $downloadResponse.ContentLength) | Out-Null
    
    $textContent = [System.Text.Encoding]::UTF8.GetString($localFile)
    
    Write-Host "📄 Content of public_html/index.php:" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Gray
    Write-Host $textContent -ForegroundColor White
    Write-Host "=" * 60 -ForegroundColor Gray
    
    $downloadStream.Close()
    $downloadResponse.Close()
    
    # Now let's try uploading to the main public_html directory instead
    Write-Host "`n💡 The issue is clear! Let's upload to public_html/ instead..." -ForegroundColor Yellow
    
    # Backup existing index.php
    Write-Host "`n📋 Creating backup of index.php..." -ForegroundColor Cyan
    $backupPath = "index-php-backup-$(Get-Date -Format 'yyyyMMdd-HHmm').php"
    [System.IO.File]::WriteAllBytes($backupPath, $localFile)
    Write-Host "✅ Backup saved as: $backupPath" -ForegroundColor Green
    
    # Upload our marketing page to the main directory
    Write-Host "`n🚀 Uploading marketing page to public_html/index.html..." -ForegroundColor Green
    
    $marketingIndexPath = Join-Path (Get-Location) "marketing-root\index.html"
    
    $uploadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/public_html/index.html")
    $uploadRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $uploadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
    $uploadRequest.UseBinary = $true
    $uploadRequest.UsePassive = $true
    
    $fileContent = [System.IO.File]::ReadAllBytes($marketingIndexPath)
    $uploadRequest.ContentLength = $fileContent.Length
    
    $requestStream = $uploadRequest.GetRequestStream()
    $requestStream.Write($fileContent, 0, $fileContent.Length)
    $requestStream.Close()
    
    $uploadResponse = $uploadRequest.GetResponse()
    Write-Host "✅ Marketing page uploaded to main public_html!" -ForegroundColor Green
    Write-Host "Response: $($uploadResponse.StatusDescription)" -ForegroundColor Cyan
    $uploadResponse.Close()
    
} catch {
    Write-Host "❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test the site
Write-Host "`n⏱️ Waiting for propagation..." -ForegroundColor Yellow
Start-Sleep 10

Write-Host "`n🔍 Testing the live site..." -ForegroundColor Cyan
try {
    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    $testResponse = curl -s "https://futurelink.zip/?v=$timestamp"
    
    if ($testResponse -match "FutureLink|Preserve Your Family Legacy") {
        Write-Host "`n🎉 SUCCESS! Marketing page is now LIVE!" -ForegroundColor Green
        Write-Host "🌐 Visit: https://futurelink.zip/" -ForegroundColor Cyan
    } else {
        Write-Host "`n📄 Current content (first 10 lines):" -ForegroundColor Yellow
        $testResponse | Select-Object -First 10 | ForEach-Object { Write-Host $_ -ForegroundColor White }
    }
} catch {
    Write-Host "⚠️ Testing failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n🌐 Visit: https://futurelink.zip/" -ForegroundColor Cyan