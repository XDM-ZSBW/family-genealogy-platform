# Explore the sites directory structure

if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#][^=]*?)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

Write-Host "🔍 Exploring family sites structure..." -ForegroundColor Cyan

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
            return $listContent
        } else {
            Write-Host "(empty directory)" -ForegroundColor Gray
            return ""
        }
    } catch {
        Write-Host "❌ Cannot list $Path`: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Explore sites directory
$sitesContent = List-FtpDirectory "sites" "Sites Directory"

if ($sitesContent) {
    # Get directory names from the listing
    $lines = $sitesContent.Split("`n") | Where-Object { $_ -match "^d" }
    foreach ($line in $lines) {
        if ($line -match "\s+(\S+)\s*$") {
            $dirName = $matches[1]
            if ($dirName -ne "." -and $dirName -ne "..") {
                Write-Host "`n🔍 Found site directory: $dirName" -ForegroundColor Cyan
                List-FtpDirectory "sites/$dirName" "Site $dirName"
            }
        }
    }
}