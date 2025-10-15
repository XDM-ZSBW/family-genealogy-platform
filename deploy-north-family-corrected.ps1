# Deploy North Family Site to family@futurelink.zip with correct subdomain path
# This script deploys to the correct family.futurelink.zip subdomain

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🚀 Deploying North Family Site to CORRECT path..." -ForegroundColor Cyan
Write-Host "Target: family.futurelink.zip/sites/north570525/" -ForegroundColor Yellow
Write-Host "Using family@futurelink.zip credentials" -ForegroundColor Yellow

$northSitePath = Join-Path (Get-Location) "2-family-sites\north570525"

if (-not (Test-Path $northSitePath)) {
    Write-Host "❌ North family site directory not found!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found North family site: $northSitePath" -ForegroundColor Green

# Get all files to upload
$filesToUpload = Get-ChildItem -Path $northSitePath -File -Filter "*.html"

Write-Host "📂 Files to upload:" -ForegroundColor Cyan
$filesToUpload | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }

# Create sites directory structure if it doesn't exist
function Create-FtpDirectory {
    param([string]$Path)
    
    try {
        Write-Host "📁 Creating directory: $Path" -ForegroundColor Yellow
        $mkdirRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name/$Path")
        $mkdirRequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
        $mkdirRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_username, $static_host_password)
        $mkdirRequest.UsePassive = $true
        
        $mkdirResponse = $mkdirRequest.GetResponse()
        Write-Host "✅ Directory created: $Path" -ForegroundColor Green
        $mkdirResponse.Close()
    } catch {
        Write-Host "⚠️  Directory may already exist: $Path" -ForegroundColor Yellow
    }
}

# Upload function
function Upload-File {
    param([string]$LocalPath, [string]$RemotePath)
    
    try {
        Write-Host "📤 Uploading: $RemotePath" -ForegroundColor Green
        
        $uploadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name/$RemotePath")
        $uploadRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $uploadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_username, $static_host_password)
        $uploadRequest.UseBinary = $true
        $uploadRequest.UsePassive = $true
        
        $fileContent = [System.IO.File]::ReadAllBytes($LocalPath)
        $uploadRequest.ContentLength = $fileContent.Length
        
        $requestStream = $uploadRequest.GetRequestStream()
        $requestStream.Write($fileContent, 0, $fileContent.Length)
        $requestStream.Close()
        
        $response = $uploadRequest.GetResponse()
        Write-Host "✅ Uploaded: $RemotePath ($($fileContent.Length) bytes)" -ForegroundColor Green
        $response.Close()
        return $true
    } catch {
        Write-Host "❌ Upload failed: $RemotePath - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Create the correct directory structure for family subdomain
# The path should be: public_html/family.futurelink.zip/sites/north570525/
Write-Host "`n🏗️  Setting up directory structure..." -ForegroundColor Cyan

Create-FtpDirectory "public_html"
Create-FtpDirectory "public_html/family.futurelink.zip" 
Create-FtpDirectory "public_html/family.futurelink.zip/sites"
Create-FtpDirectory "public_html/family.futurelink.zip/sites/north570525"

# Upload the extracted directory if it exists
$extractedPath = Join-Path $northSitePath "extracted"
if (Test-Path $extractedPath) {
    Create-FtpDirectory "public_html/family.futurelink.zip/sites/north570525/extracted"
    $extractedFiles = Get-ChildItem -Path $extractedPath -File
    foreach ($file in $extractedFiles) {
        $remotePath = "public_html/family.futurelink.zip/sites/north570525/extracted/$($file.Name)"
        Upload-File -LocalPath $file.FullName -RemotePath $remotePath
    }
}

# Upload all HTML files
$successCount = 0
foreach ($file in $filesToUpload) {
    $remotePath = "public_html/family.futurelink.zip/sites/north570525/$($file.Name)"
    if (Upload-File -LocalPath $file.FullName -RemotePath $remotePath) {
        $successCount++
    }
}

Write-Host "`n📊 Upload Summary:" -ForegroundColor Cyan
Write-Host "✅ Successful uploads: $successCount" -ForegroundColor Green
Write-Host "📁 Total files: $($filesToUpload.Count)" -ForegroundColor White

if ($successCount -eq $filesToUpload.Count) {
    Write-Host "`n🎉 SUCCESS! North Family Site deployed to CORRECT path!" -ForegroundColor Green
    Write-Host "🌐 Correct Site URL: https://family.futurelink.zip/sites/north570525/" -ForegroundColor Cyan
    
    # Test the deployment
    Write-Host "`n⏱️ Waiting for server to update..." -ForegroundColor Yellow
    Start-Sleep 15
    
    Write-Host "`n🔍 Testing live site at correct URL..." -ForegroundColor Cyan
    try {
        $testResponse = Invoke-WebRequest -Uri "https://family.futurelink.zip/sites/north570525/" -UseBasicParsing -TimeoutSec 30
        
        if ($testResponse.Content -match "North Family Genealogy|Development Prototype") {
            Write-Host "`n🎉 SUCCESS! North Family Site is LIVE at correct URL!" -ForegroundColor Green
            Write-Host "🌐 Visit: https://family.futurelink.zip/sites/north570525/" -ForegroundColor Cyan
            Write-Host "📊 Page size: $($testResponse.Content.Length) bytes" -ForegroundColor Cyan
        } else {
            Write-Host "`n⚠️ Site uploaded but content might be cached. Check manually:" -ForegroundColor Yellow
            Write-Host "🌐 https://family.futurelink.zip/sites/north570525/" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "`n⚠️ Could not test automatically. Check manually:" -ForegroundColor Yellow
        Write-Host "🌐 https://family.futurelink.zip/sites/north570525/" -ForegroundColor Cyan
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "`n⚠️ Some files failed to upload. Check the logs above." -ForegroundColor Yellow
}

Write-Host "`n📝 Note: The site should now be accessible at:" -ForegroundColor Cyan
Write-Host "   🌐 https://family.futurelink.zip/sites/north570525/" -ForegroundColor White
Write-Host "   (not futurelink.zip - notice the family. subdomain)" -ForegroundColor Yellow