# Upload test file
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

try {
    $uploadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name_root/test.html")
    $uploadRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $uploadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_user_name_root, $static_host_password_root)
    $uploadRequest.UseBinary = $true
    $uploadRequest.UsePassive = $true
    
    $fileContent = [System.IO.File]::ReadAllBytes("test.html")
    $uploadRequest.ContentLength = $fileContent.Length
    
    $requestStream = $uploadRequest.GetRequestStream()
    $requestStream.Write($fileContent, 0, $fileContent.Length)
    $requestStream.Close()
    
    $uploadResponse = $uploadRequest.GetResponse()
    Write-Host "✅ Test file uploaded" -ForegroundColor Green
    $uploadResponse.Close()
} catch {
    Write-Host "❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
}