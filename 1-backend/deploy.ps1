# Family Genealogy Platform - Deployment Script
# Deploys FastAPI backend to Google Cloud Run

param(
    [string]$ProjectId = "futurelink-platform",
    [string]$ServiceName = "family-auth-service",
    [string]$Region = "us-central1",
    [switch]$Build = $false,
    [switch]$Deploy = $false,
    [switch]$Test = $false
)

Write-Host "🚀 Family Genealogy Platform - Deployment Script" -ForegroundColor Cyan
Write-Host "=" * 60

# Check if we're in the right directory
if (-not (Test-Path "main.py")) {
    Write-Host "❌ Error: main.py not found. Please run from 1-backend directory." -ForegroundColor Red
    exit 1
}

# Check if .env exists in parent directory
if (-not (Test-Path "../.env")) {
    Write-Host "❌ Error: .env file not found in parent directory." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Environment files found" -ForegroundColor Green

# Load environment variables from .env file
Write-Host "`n🔧 Loading environment variables..."
Get-Content "../.env" | ForEach-Object {
    if ($_ -match "^([^#][^=]*?)=(.*)$") {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
        if ($name -like "*SECRET*" -or $name -like "*KEY*") {
            Write-Host "✅ $name: ***" -ForegroundColor Green
        } else {
            Write-Host "✅ $name: $value" -ForegroundColor Green
        }
    }
}

# Check required environment variables
$required_vars = @(
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET", 
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "JWT_SECRET"
)

$missing_vars = @()
foreach ($var in $required_vars) {
    if (-not [Environment]::GetEnvironmentVariable($var)) {
        $missing_vars += $var
    }
}

if ($missing_vars.Count -gt 0) {
    Write-Host "❌ Missing required environment variables: $($missing_vars -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "✅ All required environment variables configured" -ForegroundColor Green

# Build Docker image if requested
if ($Build -or $Deploy) {
    Write-Host "`n🐳 Building Docker image..."
    
    # Create .dockerignore if it doesn't exist
    if (-not (Test-Path ".dockerignore")) {
        @"
.env
__pycache__
*.pyc
*.pyo
*.pyd
.git
.gitignore
README.md
.pytest_cache
.coverage
htmlcov/
.tox/
.venv/
venv/
ENV/
env/
"@ | Out-File -FilePath ".dockerignore" -Encoding UTF8
    }
    
    $imageName = "gcr.io/$ProjectId/$ServiceName"
    
    docker build -t $imageName .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker build failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Docker image built successfully" -ForegroundColor Green
    
    # Push to Google Container Registry
    Write-Host "`n📤 Pushing image to Google Container Registry..."
    docker push $imageName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker push failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Image pushed successfully" -ForegroundColor Green
}

# Deploy to Google Cloud Run if requested
if ($Deploy) {
    Write-Host "`n☁️ Deploying to Google Cloud Run..."
    
    $env_vars = @(
        "GOOGLE_CLIENT_ID=$([Environment]::GetEnvironmentVariable('GOOGLE_CLIENT_ID'))",
        "GOOGLE_CLIENT_SECRET=$([Environment]::GetEnvironmentVariable('GOOGLE_CLIENT_SECRET'))",
        "AWS_ACCESS_KEY_ID=$([Environment]::GetEnvironmentVariable('AWS_ACCESS_KEY_ID'))",
        "AWS_SECRET_ACCESS_KEY=$([Environment]::GetEnvironmentVariable('AWS_SECRET_ACCESS_KEY'))",
        "JWT_SECRET=$([Environment]::GetEnvironmentVariable('JWT_SECRET'))",
        "SES_REGION=$([Environment]::GetEnvironmentVariable('SES_REGION') ?? 'us-west-2')",
        "SES_FROM_EMAIL=$([Environment]::GetEnvironmentVariable('SES_FROM_EMAIL') ?? 'admin@futurelink.zip')",
        "FAMILY_NAMES=$([Environment]::GetEnvironmentVariable('FAMILY_NAMES') ?? 'bull,north,klingenberg,herrman')",
        "CORS_ORIGINS=https://family.futurelink.zip,https://auth.futurelink.zip",
        "BACKEND_BASE=https://auth.futurelink.zip",
        "OAUTH_REDIRECT=https://auth.futurelink.zip/oauth/callback"
    )
    
    $env_string = ($env_vars -join ",")
    
    gcloud run deploy $ServiceName `
        --image="gcr.io/$ProjectId/$ServiceName" `
        --region=$Region `
        --platform=managed `
        --allow-unauthenticated `
        --port=8000 `
        --memory=512Mi `
        --cpu=1 `
        --max-instances=10 `
        --set-env-vars=$env_string `
        --project=$ProjectId
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Cloud Run deployment failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Deployed to Google Cloud Run successfully" -ForegroundColor Green
    
    # Get the service URL
    $serviceUrl = gcloud run services describe $ServiceName --region=$Region --project=$ProjectId --format="value(status.url)"
    Write-Host "🌐 Service URL: $serviceUrl" -ForegroundColor Cyan
    
    Write-Host "`n📋 Next steps:" -ForegroundColor Yellow
    Write-Host "1. Configure custom domain auth.futurelink.zip to point to: $serviceUrl"
    Write-Host "2. Update Google OAuth redirect URIs to include: https://auth.futurelink.zip/oauth/callback"
    Write-Host "3. Deploy family websites to family.futurelink.zip"
    Write-Host "4. Test the full OAuth flow"
}

# Test deployment if requested
if ($Test) {
    Write-Host "`n🧪 Testing deployment..."
    
    # Test local first
    Write-Host "Testing local configuration..."
    python test_email.py
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Local configuration test passed" -ForegroundColor Green
    } else {
        Write-Host "❌ Local configuration test failed" -ForegroundColor Red
    }
}

Write-Host "`n🎉 Deployment script completed!" -ForegroundColor Green
Write-Host "Use the following parameters:" -ForegroundColor Cyan
Write-Host "  -Build    : Build Docker image only"
Write-Host "  -Deploy   : Build and deploy to Google Cloud Run"
Write-Host "  -Test     : Test local configuration"
Write-Host ""
Write-Host "Example: .\deploy.ps1 -Deploy" -ForegroundColor Cyan