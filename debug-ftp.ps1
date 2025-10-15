# Debug FTP connection and upload
# Load environment variables
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🔍 Debugging FTP Connection..." -ForegroundColor Cyan
Write-Host "Host: $static_host_name_root" -ForegroundColor Green
Write-Host "User: $static_host_user_name_root" -ForegroundColor Green

# List directory contents first
try {
    Write-Host "`n📂 Listing FTP root directory..." -ForegroundColor Yellow
    $listRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/")
    $listRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
    $listRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
    $listRequest.UsePassive = $true
    
    $listResponse = $listRequest.GetResponse()
    $listStream = $listResponse.GetResponseStream()
    $listReader = New-Object System.IO.StreamReader($listStream)
    $listContent = $listReader.ReadToEnd()
    
    Write-Host "Directory contents:" -ForegroundColor Green
    Write-Host $listContent -ForegroundColor White
    
    $listReader.Close()
    $listStream.Close()
    $listResponse.Close()
} catch {
    Write-Host "❌ Failed to list directory: $($_.Exception.Message)" -ForegroundColor Red
}

# Test upload
$marketingIndexPath = Join-Path (Get-Location) "marketing-root\index.html"
if (Test-Path $marketingIndexPath) {
    Write-Host "`n📤 Testing upload to root..." -ForegroundColor Yellow
    try {
        $uploadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/index.html")
        $uploadRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $uploadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
        $uploadRequest.UseBinary = $true
        $uploadRequest.UsePassive = $true
        
        $fileContent = [System.IO.File]::ReadAllBytes($marketingIndexPath)
        $uploadRequest.ContentLength = $fileContent.Length
        
        Write-Host "File size: $($fileContent.Length) bytes" -ForegroundColor Cyan
        
        $requestStream = $uploadRequest.GetRequestStream()
        $requestStream.Write($fileContent, 0, $fileContent.Length)
        $requestStream.Close()
        
        $uploadResponse = $uploadRequest.GetResponse()
        Write-Host "✅ Upload successful!" -ForegroundColor Green
        Write-Host "Response: $($uploadResponse.StatusDescription)" -ForegroundColor Cyan
        $uploadResponse.Close()
    } catch {
        Write-Host "❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# List directory again to confirm
try {
    Write-Host "`n📂 Listing directory after upload..." -ForegroundColor Yellow
    $listRequest2 = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/")
    $listRequest2.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
    $listRequest2.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
    $listRequest2.UsePassive = $true
    
    $listResponse2 = $listRequest2.GetResponse()
    $listStream2 = $listResponse2.GetResponseStream()
    $listReader2 = New-Object System.IO.StreamReader($listStream2)
    $listContent2 = $listReader2.ReadToEnd()
    
    Write-Host "Directory contents after upload:" -ForegroundColor Green
    Write-Host $listContent2 -ForegroundColor White
    
    $listReader2.Close()
    $listStream2.Close()
    $listResponse2.Close()
} catch {
    Write-Host "❌ Failed to list directory: $($_.Exception.Message)" -ForegroundColor Red
}