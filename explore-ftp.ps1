# Explore FTP directory structure
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

function List-FtpDirectory {
    param([string]$Path)
    
    try {
        Write-Host "`n📂 Listing: $Path" -ForegroundColor Yellow
        $listRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/$Path")
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
        Write-Host "❌ Failed to list $Path`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Explore common web directories
List-FtpDirectory ""
List-FtpDirectory "public_html"
List-FtpDirectory "www" 
List-FtpDirectory "htdocs"

# Upload to public_html if it exists
$marketingIndexPath = Join-Path (Get-Location) "marketing-root\index.html"
Write-Host "`n🚀 Trying upload to public_html..." -ForegroundColor Green

try {
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
    Write-Host "✅ Upload to public_html successful!" -ForegroundColor Green
    $uploadResponse.Close()
} catch {
    Write-Host "❌ Upload to public_html failed: $($_.Exception.Message)" -ForegroundColor Red
}