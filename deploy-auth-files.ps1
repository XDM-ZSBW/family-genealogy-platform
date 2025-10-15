# Deploy Authentication Files to FTP
# This script uploads the auth-check.js and family/index.html files needed for family site authentication

Write-Host "🔐 Deploying Authentication Files to FTP..." -ForegroundColor Cyan

# Load environment variables
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
    Write-Host "✅ Loaded environment variables" -ForegroundColor Green
} else {
    Write-Host "❌ .env file not found!" -ForegroundColor Red
    exit 1
}

function Upload-File {
    param(
        [string]$LocalPath,
        [string]$RemotePath,
        [string]$Description
    )
    
    Write-Host "`n📤 Uploading $Description..." -ForegroundColor Yellow
    Write-Host "   Local: $LocalPath" -ForegroundColor Gray
    Write-Host "   Remote: $RemotePath" -ForegroundColor Gray
    
    try {
        if (!(Test-Path $LocalPath)) {
            Write-Host "   ❌ File not found: $LocalPath" -ForegroundColor Red
            return $false
        }
        
        $uploadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root$RemotePath")
        $uploadRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $uploadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
        $uploadRequest.UseBinary = $true
        $uploadRequest.UsePassive = $true
        
        $fileContent = [System.IO.File]::ReadAllBytes($LocalPath)
        $uploadRequest.ContentLength = $fileContent.Length
        
        $requestStream = $uploadRequest.GetRequestStream()
        $requestStream.Write($fileContent, 0, $fileContent.Length)
        $requestStream.Close()
        
        $uploadResponse = $uploadRequest.GetResponse()
        Write-Host "   ✅ Upload successful! ($($fileContent.Length) bytes)" -ForegroundColor Green
        $uploadResponse.Close()
        return $true
        
    } catch {
        Write-Host "   ❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Create-RemoteDirectory {
    param([string]$RemotePath)
    
    Write-Host "`n📁 Creating remote directory: $RemotePath" -ForegroundColor Yellow
    
    try {
        $createRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root$RemotePath")
        $createRequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
        $createRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
        $createRequest.UsePassive = $true
        
        $createResponse = $createRequest.GetResponse()
        Write-Host "   ✅ Directory created" -ForegroundColor Green
        $createResponse.Close()
        return $true
        
    } catch {
        if ($_.Exception.Message -like "*550*") {
            Write-Host "   ℹ️ Directory already exists or permission denied" -ForegroundColor Gray
            return $true
        }
        Write-Host "   ⚠️ Could not create directory: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Files to upload
$filesToUpload = @(
    @{
        LocalPath = "marketing-root\auth-check.js"
        RemotePath = "/auth-check.js"
        Description = "Authentication Script"
        Required = $true
    },
    @{
        LocalPath = "marketing-root\family\index.html"
        RemotePath = "/family/index.html"
        Description = "Family Gateway Page"
        Required = $true
    }
)

$successCount = 0
$totalCount = $filesToUpload.Count

# Create remote family directory first
Create-RemoteDirectory "/family"

# Upload each file
foreach ($file in $filesToUpload) {
    $success = Upload-File -LocalPath $file.LocalPath -RemotePath $file.RemotePath -Description $file.Description
    if ($success) {
        $successCount++
    } elseif ($file.Required) {
        Write-Host "`n❌ Required file upload failed. Stopping deployment." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n📊 Deployment Summary:" -ForegroundColor Cyan
Write-Host "   Files uploaded: $successCount/$totalCount" -ForegroundColor $(if ($successCount -eq $totalCount) { 'Green' } else { 'Yellow' })

if ($successCount -eq $totalCount) {
    Write-Host "`n🎉 Authentication system deployed successfully!" -ForegroundColor Green
    Write-Host "`n🔗 Test URLs:" -ForegroundColor Cyan
    Write-Host "   Gateway: https://family.futurelink.zip/family/" -ForegroundColor Blue
    Write-Host "   Auth Script: https://family.futurelink.zip/auth-check.js" -ForegroundColor Blue
    Write-Host "   North Family: https://family.futurelink.zip/sites/north570525/" -ForegroundColor Blue
    
    Write-Host "`n⚠️ Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Set up API backend at api.futurelink.zip" -ForegroundColor Gray
    Write-Host "   2. Configure Google OAuth Client ID" -ForegroundColor Gray
    Write-Host "   3. Set up SSL certificates for HTTPS" -ForegroundColor Gray
    Write-Host "   4. Test authentication flow" -ForegroundColor Gray
    
} else {
    Write-Host "`n⚠️ Some files failed to upload. Please check the errors above." -ForegroundColor Yellow
}

Write-Host "`n🚀 Deployment script completed!" -ForegroundColor Magenta