# Force deploy by deleting and re-uploading
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🗑️ Deleting existing index.html..." -ForegroundColor Yellow

# Delete existing index.html
try {
    $deleteRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/index.html")
    $deleteRequest.Method = [System.Net.WebRequestMethods+Ftp]::DeleteFile
    $deleteRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
    $deleteRequest.UsePassive = $true
    
    $deleteResponse = $deleteRequest.GetResponse()
    Write-Host "✅ Deleted old index.html" -ForegroundColor Green
    $deleteResponse.Close()
} catch {
    Write-Host "⚠️ Could not delete (may not exist): $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n⏱️ Waiting 5 seconds for server to clear cache..." -ForegroundColor Cyan
Start-Sleep 5

Write-Host "`n🚀 Uploading new marketing page..." -ForegroundColor Green

# Upload new file
$marketingIndexPath = Join-Path (Get-Location) "marketing-root\index.html"

try {
    $uploadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/index.html")
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
    Write-Host "✅ Upload successful!" -ForegroundColor Green
    $uploadResponse.Close()
    
    Write-Host "`n⏱️ Waiting for propagation..." -ForegroundColor Cyan
    Start-Sleep 10
    
    Write-Host "`n🔍 Testing the site..." -ForegroundColor Yellow
    
    # Test with cache-busting
    $testResult = curl -H "Cache-Control: no-cache" -H "Pragma: no-cache" -s https://futurelink.zip/ | Select-String -Pattern "FutureLink|Preserve Your Family Legacy"
    
    if ($testResult) {
        Write-Host "🎉 SUCCESS! Marketing page is now live!" -ForegroundColor Green
        Write-Host "🌐 Visit: https://futurelink.zip/" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️ Page uploaded but may still be cached. Try visiting in a private browser window." -ForegroundColor Yellow
        Write-Host "🌐 URL: https://futurelink.zip/" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
}