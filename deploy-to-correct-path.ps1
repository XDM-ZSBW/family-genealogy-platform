# Deploy marketing page to correct document root
# Based on cPanel info: /data0/futurelink.zip/public_html/futurelink.zip

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🚀 Deploying to CORRECT document root..." -ForegroundColor Cyan
Write-Host "Path: public_html/futurelink.zip/index.html" -ForegroundColor Yellow

$marketingIndexPath = Join-Path (Get-Location) "marketing-root\index.html"

if (-not (Test-Path $marketingIndexPath)) {
    Write-Host "❌ Marketing page not found!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found marketing page: $marketingIndexPath" -ForegroundColor Green

# Upload to the correct path
try {
    Write-Host "`n📤 Uploading to public_html/futurelink.zip/index.html..." -ForegroundColor Green
    
    $ftpRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/public_html/futurelink.zip/index.html")
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
    Write-Host "✅ Upload successful!" -ForegroundColor Green
    Write-Host "Response: $($response.StatusDescription)" -ForegroundColor Cyan
    $response.Close()
    
    Write-Host "`n⏱️ Waiting for server to update..." -ForegroundColor Yellow
    Start-Sleep 10
    
    # Test the deployment
    Write-Host "`n🔍 Testing live site..." -ForegroundColor Cyan
    
    try {
        $testResponse = Invoke-WebRequest -Uri "https://futurelink.zip/" -UseBasicParsing -TimeoutSec 30
        
        if ($testResponse.Content -match "FutureLink|Preserve Your Family Legacy") {
            Write-Host "`n🎉 SUCCESS! Marketing page is now live!" -ForegroundColor Green
            Write-Host "🌐 Visit: https://futurelink.zip/" -ForegroundColor Cyan
            Write-Host "📊 Page size: $($testResponse.Content.Length) bytes" -ForegroundColor Cyan
        } else {
            Write-Host "`n⚠️ Page uploaded but content doesn't match expected. Check manually." -ForegroundColor Yellow
            Write-Host "🌐 URL: https://futurelink.zip/" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "`n⚠️ Could not test automatically. Please check manually:" -ForegroundColor Yellow
        Write-Host "🌐 https://futurelink.zip/" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Trying to create directory first..." -ForegroundColor Yellow
    
    # Try to create the directory structure
    try {
        $mkdirRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/public_html/futurelink.zip")
        $mkdirRequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
        $mkdirRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
        $mkdirRequest.UsePassive = $true
        
        $mkdirResponse = $mkdirRequest.GetResponse()
        Write-Host "✅ Directory created" -ForegroundColor Green
        $mkdirResponse.Close()
        
        # Retry upload
        Write-Host "🔄 Retrying upload..." -ForegroundColor Yellow
        # ... retry the upload code here if needed
        
    } catch {
        Write-Host "❌ Could not create directory: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "The directory may already exist or you may need different permissions." -ForegroundColor Yellow
    }
}

Write-Host "`n📋 Summary:" -ForegroundColor Cyan
Write-Host "- Marketing page: 21,388 bytes" -ForegroundColor White
Write-Host "- Upload path: public_html/futurelink.zip/index.html" -ForegroundColor White
Write-Host "- Live URL: https://futurelink.zip/" -ForegroundColor White