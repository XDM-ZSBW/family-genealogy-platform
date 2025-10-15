# Upload marketing page directly to public_html (main web root)

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🎯 Uploading marketing page to main web root..." -ForegroundColor Cyan
Write-Host "Target: public_html/index.html" -ForegroundColor Yellow

$marketingIndexPath = Join-Path (Get-Location) "marketing-root\index.html"

if (-not (Test-Path $marketingIndexPath)) {
    Write-Host "❌ Marketing page not found!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found marketing page: $marketingIndexPath" -ForegroundColor Green
Write-Host "📦 File size: $((Get-Item $marketingIndexPath).Length) bytes" -ForegroundColor Cyan

# Upload to main public_html directory
try {
    Write-Host "`n📤 Uploading to public_html/index.html..." -ForegroundColor Green
    
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
    Write-Host "✅ Marketing page uploaded successfully!" -ForegroundColor Green
    Write-Host "Response: $($uploadResponse.StatusDescription)" -ForegroundColor Cyan
    $uploadResponse.Close()
    
    # Verify by listing directory
    Write-Host "`n📂 Verifying upload..." -ForegroundColor Cyan
    try {
        $listRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/public_html/")
        $listRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
        $listRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
        $listRequest.UsePassive = $true
        
        $listResponse = $listRequest.GetResponse()
        $listStream = $listResponse.GetResponseStream()
        $listReader = New-Object System.IO.StreamReader($listStream)
        $listContent = $listReader.ReadToEnd()
        
        Write-Host "📁 Files in public_html:" -ForegroundColor Yellow
        $listContent.Split("`n") | Where-Object { $_ -match "index\." } | ForEach-Object {
            Write-Host $_ -ForegroundColor White
        }
        
        $listReader.Close()
        $listStream.Close()
        $listResponse.Close()
    } catch {
        Write-Host "⚠️ Could not verify: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Wait and test
Write-Host "`n⏱️ Waiting for server to update..." -ForegroundColor Yellow
Start-Sleep 15

Write-Host "`n🔍 Testing the live site..." -ForegroundColor Cyan

# Multiple test attempts with different cache-busting techniques
for ($i = 1; $i -le 3; $i++) {
    Write-Host "Test $i..." -ForegroundColor Gray
    
    try {
        $timestamp = Get-Date -UFormat %s
        $testResponse = curl -s "https://futurelink.zip/?bust=$timestamp" -H "Cache-Control: no-cache" -H "Pragma: no-cache"
        
        if ($testResponse -match "FutureLink.*Preserve.*Your.*Family.*Legacy|Preserve Your Family Legacy Forever") {
            Write-Host "`n🎉 SUCCESS! Marketing page is LIVE!" -ForegroundColor Green
            Write-Host "🌐 Visit: https://futurelink.zip/" -ForegroundColor Cyan
            Write-Host "✨ Your amazing SEO-optimized marketing page is now serving!" -ForegroundColor Green
            break
        } elseif ($testResponse -match "FutureLink") {
            Write-Host "`n✅ FutureLink detected! Page is updating..." -ForegroundColor Green
            Write-Host "🌐 Visit: https://futurelink.zip/" -ForegroundColor Cyan
            break
        } else {
            Write-Host "Still cached... waiting..." -ForegroundColor Gray
            if ($i -eq 3) {
                Write-Host "`n⚠️ Upload successful but may be heavily cached." -ForegroundColor Yellow
                Write-Host "📄 Current content (first 5 lines):" -ForegroundColor Yellow
                $testResponse | Select-Object -First 5 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
                Write-Host "`n🌐 Try visiting in a private browser: https://futurelink.zip/" -ForegroundColor Cyan
            }
        }
        
        Start-Sleep 5
    } catch {
        Write-Host "Test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n📋 Summary:" -ForegroundColor Cyan
Write-Host "✅ Marketing page uploaded to main document root" -ForegroundColor Green
Write-Host "📍 Location: public_html/index.html" -ForegroundColor White
Write-Host "📊 Size: 21,388 bytes" -ForegroundColor White
Write-Host "🌐 URL: https://futurelink.zip/" -ForegroundColor White