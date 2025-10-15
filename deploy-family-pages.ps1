# Deploy family pages with development headers
# Uses family@futurelink.zip credentials

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🏛️ Deploying family pages with development headers..." -ForegroundColor Cyan
Write-Host "Using family@futurelink.zip credentials" -ForegroundColor Yellow

# Check family credentials are available
if (-not $static_host_name -or -not $static_host_username -or -not $static_host_password) {
    Write-Host "❌ Missing family FTP credentials in .env" -ForegroundColor Red
    Write-Host "Required: static_host_name, static_host_username, static_host_password" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Using credentials:" -ForegroundColor Green
Write-Host "  Host: $static_host_name" -ForegroundColor Green
Write-Host "  User: $static_host_username" -ForegroundColor Green
Write-Host "  Pass: ***" -ForegroundColor Green

# List existing family directories first
function List-FtpDirectory {
    param([string]$Path, [string]$Description)
    
    try {
        Write-Host "`n📂 $Description`: $Path" -ForegroundColor Yellow
        $listRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name/$Path")
        $listRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
        $listRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_username, $static_host_password)
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
        return $listContent
    } catch {
        Write-Host "❌ Cannot list $Path`: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# First explore the structure
List-FtpDirectory "" "FTP Root"
List-FtpDirectory "public_html" "Public HTML"

# Check for existing family directories
$familyDirs = @("bull", "north", "klingenberg", "herrman")

foreach ($family in $familyDirs) {
    Write-Host "`n🔍 Checking family directory: $family" -ForegroundColor Cyan
    $content = List-FtpDirectory "public_html/family.$family" "Family $family"
    
    if ($content) {
        Write-Host "✅ Found $family family directory" -ForegroundColor Green
        
        # Download existing index.html to modify
        try {
            Write-Host "📥 Downloading existing index.html for $family..." -ForegroundColor Yellow
            
            $downloadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name/public_html/family.$family/index.html")
            $downloadRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
            $downloadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_username, $static_host_password)
            $downloadRequest.UsePassive = $true
            
            $downloadResponse = $downloadRequest.GetResponse()
            $downloadStream = $downloadResponse.GetResponseStream()
            
            $localFile = New-Object byte[] $downloadResponse.ContentLength
            $downloadStream.Read($localFile, 0, $downloadResponse.ContentLength) | Out-Null
            
            $originalContent = [System.Text.Encoding]::UTF8.GetString($localFile)
            
            $downloadStream.Close()
            $downloadResponse.Close()
            
            # Add development header if not already present
            if ($originalContent -notmatch "dev-prototype-banner") {
                Write-Host "🔧 Adding development header to $family..." -ForegroundColor Green
                
                # Read the dev header
                $devHeader = Get-Content "2-family-sites\shared\dev-header.html" -Raw -Encoding UTF8
                
                # Insert after the opening body tag
                if ($originalContent -match "(<body[^>]*>)") {
                    $modifiedContent = $originalContent -replace "(<body[^>]*>)", "`$1`n$devHeader`n"
                    
                    # Create backup
                    $backupPath = "family-$family-backup-$(Get-Date -Format 'yyyyMMdd-HHmm').html"
                    [System.IO.File]::WriteAllBytes($backupPath, $localFile)
                    Write-Host "✅ Backup saved: $backupPath" -ForegroundColor Green
                    
                    # Upload modified version
                    $modifiedBytes = [System.Text.Encoding]::UTF8.GetBytes($modifiedContent)
                    
                    $uploadRequest = [System.Net.FtpWebRequest]::Create("ftp://$static_host_name/public_html/family.$family/index.html")
                    $uploadRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
                    $uploadRequest.Credentials = New-Object System.Net.NetworkCredential($static_host_username, $static_host_password)
                    $uploadRequest.UseBinary = $true
                    $uploadRequest.UsePassive = $true
                    
                    $uploadRequest.ContentLength = $modifiedBytes.Length
                    
                    $requestStream = $uploadRequest.GetRequestStream()
                    $requestStream.Write($modifiedBytes, 0, $modifiedBytes.Length)
                    $requestStream.Close()
                    
                    $uploadResponse = $uploadRequest.GetResponse()
                    Write-Host "✅ Updated $family family page with dev header!" -ForegroundColor Green
                    $uploadResponse.Close()
                    
                } else {
                    Write-Host "⚠️ Could not find body tag in $family index.html" -ForegroundColor Yellow
                }
            } else {
                Write-Host "ℹ️ Development header already present in $family" -ForegroundColor Cyan
            }
            
        } catch {
            Write-Host "❌ Failed to process $family`: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️ $family family directory not found or empty" -ForegroundColor Yellow
    }
}

Write-Host "`n🎉 Family pages deployment completed!" -ForegroundColor Green
Write-Host "📋 Summary:" -ForegroundColor Cyan
Write-Host "- Development headers added to existing family pages" -ForegroundColor White
Write-Host "- Backups created for all modified files" -ForegroundColor White
Write-Host "- Family pages now show prototype status" -ForegroundColor White