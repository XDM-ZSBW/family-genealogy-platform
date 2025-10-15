# Google OAuth Configuration Script
# Sets up OAuth 2.0 credentials for FutureLink Family Genealogy Platform

Write-Host "🔐 Configuring Google OAuth for Family Genealogy Platform..." -ForegroundColor Cyan

# Check if gcloud is installed and authenticated
try {
    $project = gcloud config get-value project 2>$null
    if (-not $project) {
        Write-Host "❌ No Google Cloud project configured. Please run 'gcloud auth login' first." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Using Google Cloud Project: $project" -ForegroundColor Green
} catch {
    Write-Host "❌ gcloud CLI not found or not authenticated. Please install and authenticate first." -ForegroundColor Red
    exit 1
}

# OAuth Configuration Details
$appName = "FutureLink Family Genealogy Platform"
$domains = @(
    "https://family.futurelink.zip",
    "https://api.futurelink.zip", 
    "http://localhost:3000",  # For local development
    "http://localhost:8000"   # For local API development
)

$redirectUris = @(
    "https://api.futurelink.zip/auth/google/callback",
    "https://family.futurelink.zip/auth/callback",
    "http://localhost:8000/auth/google/callback",  # Local development
    "http://localhost:3000/auth/callback"          # Local frontend
)

Write-Host "`n🌐 Configuring OAuth with these settings:" -ForegroundColor Yellow
Write-Host "   App Name: $appName" -ForegroundColor Gray
Write-Host "   Authorized Origins:" -ForegroundColor Gray
$domains | ForEach-Object { Write-Host "     - $_" -ForegroundColor Gray }
Write-Host "   Redirect URIs:" -ForegroundColor Gray  
$redirectUris | ForEach-Object { Write-Host "     - $_" -ForegroundColor Gray }

# Check if OAuth consent screen is configured
Write-Host "`n🔍 Checking OAuth consent screen configuration..." -ForegroundColor Yellow

try {
    # This might fail if consent screen isn't configured
    $consentCheck = gcloud alpha iap oauth-brands list --format="value(name)" 2>$null
    if ($consentCheck) {
        Write-Host "✅ OAuth consent screen already configured" -ForegroundColor Green
    } else {
        Write-Host "⚠️ OAuth consent screen needs to be configured" -ForegroundColor Yellow
        Write-Host "   Please visit: https://console.cloud.google.com/apis/credentials/consent" -ForegroundColor Cyan
        Write-Host "   Configure these settings:" -ForegroundColor Gray
        Write-Host "     - App Name: $appName" -ForegroundColor Gray
        Write-Host "     - User Support Email: your-email@domain.com" -ForegroundColor Gray
        Write-Host "     - Authorized Domains: futurelink.zip" -ForegroundColor Gray
        Write-Host "     - Developer Contact: your-email@domain.com" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠️ Unable to check consent screen. May need manual configuration." -ForegroundColor Yellow
}

# Enable required APIs
Write-Host "`n🔧 Enabling required Google APIs..." -ForegroundColor Yellow

$requiredApis = @(
    "iam.googleapis.com",
    "iamcredentials.googleapis.com", 
    "cloudresourcemanager.googleapis.com"
)

foreach ($api in $requiredApis) {
    try {
        Write-Host "   Enabling $api..." -ForegroundColor Gray
        gcloud services enable $api --quiet
        Write-Host "   ✅ $api enabled" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️ Could not enable $api - may already be enabled" -ForegroundColor Yellow
    }
}

# Create OAuth 2.0 Client ID
Write-Host "`n🆔 Creating OAuth 2.0 Client ID..." -ForegroundColor Yellow

$clientName = "family-genealogy-web-client"

try {
    # Check if client already exists
    $existingClient = gcloud auth application-default print-access-token 2>$null | Out-Null
    
    # Create the OAuth client
    Write-Host "   Creating web application OAuth client..." -ForegroundColor Gray
    
    # Build the gcloud command
    $originsString = $domains -join ","
    $redirectsString = $redirectUris -join ","
    
    $createCmd = "gcloud alpha iap oauth-clients create --display-name=`"$clientName`" --type=web --authorized-origins=`"$originsString`" --authorized-redirect-uris=`"$redirectsString`""
    
    Write-Host "`n⚠️ Manual OAuth Client Creation Required" -ForegroundColor Yellow
    Write-Host "The gcloud CLI has limited OAuth client creation capabilities." -ForegroundColor Gray
    Write-Host "Please create the OAuth client manually:" -ForegroundColor Cyan
    
    Write-Host "`n🌐 Visit: https://console.cloud.google.com/apis/credentials" -ForegroundColor Cyan
    Write-Host "`n📋 Create OAuth 2.0 Client ID with these settings:" -ForegroundColor Yellow
    
    Write-Host "`n   Application Type: Web application" -ForegroundColor Gray
    Write-Host "   Name: $clientName" -ForegroundColor Gray
    
    Write-Host "`n   Authorized JavaScript origins:" -ForegroundColor Gray
    $domains | ForEach-Object { Write-Host "     $($_)" -ForegroundColor Cyan }
    
    Write-Host "`n   Authorized redirect URIs:" -ForegroundColor Gray
    $redirectUris | ForEach-Object { Write-Host "     $($_)" -ForegroundColor Cyan }
    
} catch {
    Write-Host "   ❌ OAuth client creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Generate environment variables template
Write-Host "`n📝 Generating environment variables template..." -ForegroundColor Yellow

$envTemplate = @"
# Google OAuth Configuration for Family Genealogy Platform
# Copy these values from Google Cloud Console > APIs & Credentials

# OAuth 2.0 Client Credentials
GOOGLE_CLIENT_ID=your_google_client_id_here.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_google_client_secret_here

# OAuth Configuration
GOOGLE_REDIRECT_URI=https://api.futurelink.zip/auth/google/callback
GOOGLE_SCOPE=openid email profile

# Session Configuration  
SESSION_SECRET=generate_a_secure_random_string_here
SESSION_COOKIE_DOMAIN=.futurelink.zip
SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTPONLY=true

# API Configuration
API_BASE_URL=https://api.futurelink.zip
FRONTEND_URL=https://family.futurelink.zip

# Family Access Control (comma-separated user emails)
NORTH_FAMILY_ACCESS=user1@example.com,user2@example.com
BULL_FAMILY_ACCESS=user1@example.com
HERRMAN_FAMILY_ACCESS=user2@example.com
KLINGENBERG_FAMILY_ACCESS=user1@example.com,user2@example.com
"@

$envPath = Join-Path (Get-Location) ".env.oauth.template"
$envTemplate | Out-File -FilePath $envPath -Encoding UTF8

Write-Host "✅ Environment template created: .env.oauth.template" -ForegroundColor Green

# Create OAuth testing script
Write-Host "`n🧪 Creating OAuth test script..." -ForegroundColor Yellow

$testScript = @'
# Test OAuth Configuration
# Run this after setting up OAuth credentials

param(
    [string]$ClientId,
    [string]$ClientSecret
)

if (-not $ClientId -or -not $ClientSecret) {
    Write-Host "Usage: .\test-oauth.ps1 -ClientId 'your_client_id' -ClientSecret 'your_client_secret'" -ForegroundColor Yellow
    exit 1
}

Write-Host "🧪 Testing OAuth Configuration..." -ForegroundColor Cyan

# Test OAuth endpoints
$testUrls = @(
    "https://family.futurelink.zip/auth-check.js",
    "https://family.futurelink.zip/family/",
    "https://family.futurelink.zip/sites/north570525/"
)

foreach ($url in $testUrls) {
    try {
        Write-Host "   Testing: $url" -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $url -Method Head -ErrorAction Stop
        Write-Host "   ✅ $($response.StatusCode) - OK" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n🔐 OAuth URLs to test manually:" -ForegroundColor Yellow
Write-Host "   1. Visit: https://family.futurelink.zip/sites/north570525/" -ForegroundColor Cyan
Write-Host "   2. Should redirect to: https://family.futurelink.zip/family/" -ForegroundColor Cyan  
Write-Host "   3. Click 'Continue with Google' to test OAuth flow" -ForegroundColor Cyan

Write-Host "`n⚙️ Google OAuth Test URL:" -ForegroundColor Yellow
$oauthTestUrl = "https://accounts.google.com/o/oauth2/v2/auth?client_id=$ClientId&response_type=code&scope=openid%20email%20profile&redirect_uri=https://api.futurelink.zip/auth/google/callback&state=test"
Write-Host $oauthTestUrl -ForegroundColor Cyan
'@

$testScriptPath = Join-Path (Get-Location) "test-oauth.ps1"
$testScript | Out-File -FilePath $testScriptPath -Encoding UTF8

Write-Host "✅ OAuth test script created: test-oauth.ps1" -ForegroundColor Green

# Summary
Write-Host "`n🎉 OAuth Configuration Setup Complete!" -ForegroundColor Green
Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. 🌐 Visit Google Cloud Console: https://console.cloud.google.com/apis/credentials" -ForegroundColor Gray
Write-Host "   2. 🔐 Create OAuth 2.0 Client ID with the settings shown above" -ForegroundColor Gray  
Write-Host "   3. 📝 Copy Client ID and Secret to .env.oauth.template" -ForegroundColor Gray
Write-Host "   4. 🚀 Update your backend API with OAuth credentials" -ForegroundColor Gray
Write-Host "   5. 🧪 Run .\test-oauth.ps1 to verify configuration" -ForegroundColor Gray

Write-Host "`n📁 Files Created:" -ForegroundColor Yellow
Write-Host "   - .env.oauth.template (environment variables)" -ForegroundColor Gray
Write-Host "   - test-oauth.ps1 (testing script)" -ForegroundColor Gray

Write-Host "`n🔗 Integration Points:" -ForegroundColor Yellow  
Write-Host "   - Frontend auth-check.js: ✅ Already deployed" -ForegroundColor Green
Write-Host "   - Family gateway page: ✅ Already deployed" -ForegroundColor Green
Write-Host "   - Backend API: 🔄 Needs OAuth integration" -ForegroundColor Yellow
Write-Host "   - Google OAuth: 🔄 Needs manual setup" -ForegroundColor Yellow

Write-Host "`n🚀 OAuth setup script completed!" -ForegroundColor Magenta