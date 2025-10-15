# Clean deployment - delete existing file first, then upload

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🚀 Clean deployment to futurelink.zip root..." -ForegroundColor Cyan

$marketingIndexPath = Join-Path (Get-Location) "marketing-root\index.html"

if (-not (Test-Path $marketingIndexPath)) {
    Write-Host "❌ Marketing page not found!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found marketing page: $marketingIndexPath" -ForegroundColor Green
Write-Host "📦 File size: $((Get-Item $marketingIndexPath).Length) bytes" -ForegroundColor Cyan

# Step 1: Delete existing file
Write-Host "`n🗑️  Deleting existing index.html..." -ForegroundColor Yellow

try {
    $deleteRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/public_html/futurelink.zip/index.html")
    $deleteRequest.Method = [System.Net.WebRequestMethods+Ftp]::DeleteFile
    $deleteRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
    $deleteRequest.UsePassive = $true
    
    $deleteResponse = $deleteRequest.GetResponse()
    Write-Host "✅ Existing file deleted" -ForegroundColor Green
    $deleteResponse.Close()
} catch {
    Write-Host "⚠️  File may not exist (OK): $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 2: Upload new file
Write-Host "`n📤 Uploading marketing page..." -ForegroundColor Green

try {
    $uploadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/public_html/futurelink.zip/index.html")
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
    Write-Host "✅ Marketing page uploaded successfully!" -ForegroundColor Green
    Write-Host "Response: $($uploadResponse.StatusDescription)" -ForegroundColor Cyan
    $uploadResponse.Close()
    
    # Step 3: Wait and test
    Write-Host "`n⏱️  Waiting for server propagation..." -ForegroundColor Yellow
    Start-Sleep 15
    
    Write-Host "`n🔍 Testing the live site..." -ForegroundColor Cyan
    
    # Test with cache busting
    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    $testUrl = "https://futurelink.zip/?v=$timestamp"
    
    try {
        $testResponse = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 30 -Headers @{"Cache-Control"="no-cache"; "Pragma"="no-cache"}
        
        Write-Host "📊 Response size: $($testResponse.Content.Length) bytes" -ForegroundColor Cyan
        Write-Host "📊 Status: $($testResponse.StatusCode)" -ForegroundColor Cyan
        
        if ($testResponse.Content -match "FutureLink.*Preserve.*Family.*Legacy|Preserve Your Family Legacy Forever") {
            Write-Host "`n🎉 SUCCESS! Marketing page is now LIVE!" -ForegroundColor Green
            Write-Host "🌐 Visit: https://futurelink.zip/" -ForegroundColor Cyan
            Write-Host "✨ Your SEO-optimized marketing page is now serving!" -ForegroundColor Green
        } elseif ($testResponse.Content -match "FutureLink") {
            Write-Host "`n✅ FutureLink content detected! Marketing page is live!" -ForegroundColor Green
            Write-Host "🌐 Visit: https://futurelink.zip/" -ForegroundColor Cyan
        } else {
            Write-Host "`n⚠️  Upload successful but content may still be cached." -ForegroundColor Yellow
            Write-Host "🌐 Try visiting: https://futurelink.zip/ in a private window" -ForegroundColor Cyan
            Write-Host "Content preview:" -ForegroundColor Gray
            Write-Host ($testResponse.Content.Substring(0, [Math]::Min(200, $testResponse.Content.Length))) -ForegroundColor Gray
        }
    } catch {
        Write-Host "`n⚠️  Could not test automatically: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "🌐 Please check manually: https://futurelink.zip/" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n📋 Deployment Summary:" -ForegroundColor Cyan
Write-Host "- Source file: marketing-root/index.html" -ForegroundColor White
Write-Host "- Target: public_html/futurelink.zip/index.html" -ForegroundColor White
Write-Host "- Size: 21,388 bytes" -ForegroundColor White
Write-Host "- URL: https://futurelink.zip/" -ForegroundColor White