# Add development header to Bull family site

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🐂 Adding development header to Bull family site..." -ForegroundColor Cyan

# Download the Bull family index.html
try {
    Write-Host "📥 Downloading Bull family index.html..." -ForegroundColor Yellow
    
    $downloadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name/sites/bull513684/index.html")
    $downloadRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $downloadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_username, $static_host_password)
    $downloadRequest.UsePassive = $true
    
    $downloadResponse = $downloadRequest.GetResponse()
    $downloadStream = $downloadResponse.GetResponseStream()
    
    $buffer = New-Object byte[] 4096
    $totalRead = 0
    $allBytes = @()
    
    do {
        $read = $downloadStream.Read($buffer, 0, $buffer.Length)
        if ($read -gt 0) {
            $chunk = New-Object byte[] $read
            [Array]::Copy($buffer, 0, $chunk, 0, $read)
            $allBytes += $chunk
            $totalRead += $read
        }
    } while ($read -gt 0)
    
    $originalContent = [System.Text.Encoding]::UTF8.GetString($allBytes)
    
    $downloadStream.Close()
    $downloadResponse.Close()
    
    Write-Host "✅ Downloaded $totalRead bytes" -ForegroundColor Green
    
    # Check if development header is already present
    if ($originalContent -match "dev-prototype-banner") {
        Write-Host "ℹ️ Development header already present in Bull family site" -ForegroundColor Cyan
        return
    }
    
    # Read the dev header
    Write-Host "🔧 Adding development header..." -ForegroundColor Green
    $devHeader = Get-Content "2-family-sites\shared\dev-header.html" -Raw -Encoding UTF8
    
    # Insert after the opening body tag
    if ($originalContent -match "(<body[^>]*>)") {
        $modifiedContent = $originalContent -replace "(<body[^>]*>)", "`$1`n$devHeader`n"
        
        # Create backup
        $backupPath = "bull-family-backup-$(Get-Date -Format 'yyyyMMdd-HHmm').html"
        [System.IO.File]::WriteAllBytes($backupPath, $allBytes)
        Write-Host "✅ Backup saved: $backupPath" -ForegroundColor Green
        
        # Upload modified version
        $modifiedBytes = [System.Text.Encoding]::UTF8.GetBytes($modifiedContent)
        
        $uploadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name/sites/bull513684/index.html")
        $uploadRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $uploadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_username, $static_host_password)
        $uploadRequest.UseBinary = $true
        $uploadRequest.UsePassive = $true
        
        $uploadRequest.ContentLength = $modifiedBytes.Length
        
        $requestStream = $uploadRequest.GetRequestStream()
        $requestStream.Write($modifiedBytes, 0, $modifiedBytes.Length)
        $requestStream.Close()
        
        $uploadResponse = $uploadRequest.GetResponse()
        Write-Host "✅ Updated Bull family page with development header!" -ForegroundColor Green
        Write-Host "📊 New file size: $($modifiedBytes.Length) bytes" -ForegroundColor Cyan
        $uploadResponse.Close()
        
    } else {
        Write-Host "⚠️ Could not find body tag in Bull family index.html" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Failed to process Bull family site: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎉 Bull family site update completed!" -ForegroundColor Green