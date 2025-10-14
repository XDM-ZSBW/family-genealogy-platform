# Upload index.html to domain root
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

$indexPath = Join-Path (Get-Location) "2-family-sites\index.html"

Write-Host "🚀 Uploading index.html to domain root..." -ForegroundColor Green

try {
    $ftpRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name/index.html")
    $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $ftpRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_username, $static_host_password)
    $ftpRequest.UseBinary = $true
    $ftpRequest.UsePassive = $true
    
    $fileContent = [System.IO.File]::ReadAllBytes($indexPath)
    $ftpRequest.ContentLength = $fileContent.Length
    
    $requestStream = $ftpRequest.GetRequestStream()
    $requestStream.Write($fileContent, 0, $fileContent.Length)
    $requestStream.Close()
    
    $response = $ftpRequest.GetResponse()
    Write-Host "✅ Uploaded index.html to domain root" -ForegroundColor Green
    Write-Host "🔗 Visit: https://family.futurelink.zip" -ForegroundColor Cyan
    $response.Close()
} catch {
    Write-Host "❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
}