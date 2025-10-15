# List contents and then deploy

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🔍 Checking FTP directory structure..." -ForegroundColor Cyan

function List-FtpDirectory {
    param([string]$Path, [string]$Description)
    
    try {
        Write-Host "`n📂 $Description`: $Path" -ForegroundColor Yellow
        $listRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/$Path")
        $listRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
        $listRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
        $listRequest.UsePassive = $true
        
        $listResponse = $listRequest.GetResponse()
        $listStream = $listResponse.GetResponseStream()
        $listReader = New-Object System.IO.StreamReader($listStream)
        $listContent = $listReader.ReadToEnd()
        
        if ($listContent.Trim()) {
            Write-Host $listContent -ForegroundColor White
        } else {
            Write-Host "(empty directory)" -ForegroundColor Gray
        }
        
        $listReader.Close()
        $listStream.Close()
        $listResponse.Close()
    } catch {
        Write-Host "❌ Cannot list $Path`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# List key directories
List-FtpDirectory "" "FTP Root"
List-FtpDirectory "public_html" "Public HTML"
List-FtpDirectory "public_html/futurelink.zip" "Domain Directory"

Write-Host "`n🚀 Starting deployment..." -ForegroundColor Green

$marketingIndexPath = Join-Path (Get-Location) "marketing-root\index.html"

if (-not (Test-Path $marketingIndexPath)) {
    Write-Host "❌ Marketing page not found!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found marketing page: $marketingIndexPath" -ForegroundColor Green
Write-Host "📦 File size: $((Get-Item $marketingIndexPath).Length) bytes" -ForegroundColor Cyan

# Delete existing file
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

# Upload new file
Write-Host "`n📤 Uploading to public_html/futurelink.zip/index.html..." -ForegroundColor Green

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
    
    # Verify upload
    Write-Host "`n📂 Verifying upload - listing directory after upload:" -ForegroundColor Cyan
    List-FtpDirectory "public_html/futurelink.zip" "After Upload"
    
} catch {
    Write-Host "❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🔍 Testing the live site..." -ForegroundColor Cyan

# Test the site
Start-Sleep 5
$timestamp = [int][double]::Parse((Get-Date -UFormat %s))
try {
    $testResponse = curl -s "https://futurelink.zip/?v=$timestamp" 
    $preview = $testResponse | Select-Object -First 5
    
    Write-Host "Site content preview:" -ForegroundColor Yellow
    Write-Host ($preview -join "`n") -ForegroundColor White
    
    if ($testResponse -match "FutureLink|Preserve Your Family Legacy") {
        Write-Host "`n🎉 SUCCESS! Marketing page is LIVE!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  Content may still be cached or different issue" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Testing failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n🌐 Visit: https://futurelink.zip/" -ForegroundColor Cyan