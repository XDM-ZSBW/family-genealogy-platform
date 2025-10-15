# Check for web configuration files
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

function Download-FtpFile {
    param([string]$FileName)
    
    try {
        Write-Host "`n📥 Downloading: $FileName" -ForegroundColor Yellow
        $downloadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/$FileName")
        $downloadRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
        $downloadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
        $downloadRequest.UsePassive = $true
        
        $downloadResponse = $downloadRequest.GetResponse()
        $downloadStream = $downloadResponse.GetResponseStream()
        
        $localFile = New-Object byte[] $downloadResponse.ContentLength
        $downloadStream.Read($localFile, 0, $downloadResponse.ContentLength) | Out-Null
        
        Write-Host "Content of $FileName (first 500 chars):" -ForegroundColor Green
        $textContent = [System.Text.Encoding]::UTF8.GetString($localFile)
        Write-Host $textContent.Substring(0, [Math]::Min(500, $textContent.Length)) -ForegroundColor White
        
        $downloadStream.Close()
        $downloadResponse.Close()
    } catch {
        Write-Host "❌ Failed to download $FileName`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Check common config files
Download-FtpFile ".htaccess"
Download-FtpFile "index.php"
Download-FtpFile "index.html"

# List all files with details
try {
    Write-Host "`n📂 All files in root:" -ForegroundColor Yellow
    $listRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/")
    $listRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    $listRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
    $listRequest.UsePassive = $true
    
    $listResponse = $listRequest.GetResponse()
    $listStream = $listResponse.GetResponseStream()
    $listReader = New-Object System.IO.StreamReader($listStream)
    $listContent = $listReader.ReadToEnd()
    
    Write-Host $listContent -ForegroundColor White
    
    $listReader.Close()
    $listStream.Close()
    $listResponse.Close()
} catch {
    Write-Host "❌ Failed to list files" -ForegroundColor Red
}