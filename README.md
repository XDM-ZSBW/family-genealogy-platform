# Family Genealogy Platform

🏛️ **Multi-family genealogy platform hosted at `family.futurelink.zip`**

## 📖 Overview

This platform hosts multiple family genealogy websites with shared authentication, email marketing consent, and family-specific access control. Each family gets their own path on the domain.

## 🌐 Live URLs

- **Main Platform**: https://family.futurelink.zip
- **Auth Service**: https://auth.futurelink.zip (Oracle VM)

### Family Sites
- **Bull Family** (Gladys Klingenberg): https://family.futurelink.zip/bull
- **North Family**: https://family.futurelink.zip/north
- **Klingenberg Family**: https://family.futurelink.zip/klingenberg  
- **Herrman Family**: https://family.futurelink.zip/herrman

## 🏗️ Architecture

```
family-genealogy-platform/
├── 0-infra/                # Oracle VM infrastructure (Terraform/Ansible)
├── 1-backend/              # FastAPI authentication service
├── 2-family-sites/         # Static family websites
│   ├── bull/               # Gladys Klingenberg wiki content
│   ├── north/              # North family content (future)
│   ├── klingenberg/        # Klingenberg family content (future)
│   └── herrman/            # Herrman family content (future)
├── 3-shared/               # Common authentication assets
├── scripts/                # Deployment automation
├── .env.example            # Environment configuration template
└── README.md
```

## 🔐 Authentication Flow

1. **User visits family site** → `family.futurelink.zip/bull`
2. **Auth check** → JavaScript detects no valid JWT
3. **Redirect to login** → `family.futurelink.zip/shared/login.html?family=bull`
4. **Google OAuth** → User signs in with Google account
5. **Email verification** → Amazon SES sends verification code
6. **Access granted** → JWT cookie allows access to authorized families
7. **Marketing consent** → Optional opt-in for family-specific newsletters

## 🛠️ Technology Stack

### Backend (Oracle VM)
- **FastAPI** - Authentication service
- **SQLite + SQLModel** - User and family access database
- **Google OAuth 2.0** - Identity verification
- **Amazon SES** - Email verification and marketing
- **Docker + systemd** - Deployment and service management

### Frontend (Porkbun Hosting)
- **Static HTML/CSS/JS** - Family websites
- **Shared authentication** - JavaScript auth wrapper
- **Family-aware routing** - Path-based family detection
- **Responsive design** - Mobile-friendly layouts

### DevOps
- **PowerShell** - Deployment automation (Windows-compatible)
- **python-dotenv** - Environment configuration
- **GitHub Actions** - CI/CD pipeline
- **Porkbun API** - Static hosting deployment

## ⚙️ Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Porkbun (static_ prefix required)
static_PORKBUN_API_KEY=your_api_key
static_PORKBUN_SECRET=your_secret

# Google OAuth
GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_client_secret

# Amazon SES
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret

# Family Configuration
FAMILY_NAMES=bull,north,klingenberg,herrman
DEFAULT_FAMILY=bull
```

See `.env.example` for complete configuration options.

## 🚀 Deployment

### Backend Deployment (Oracle VM)
```powershell
# Build and deploy auth service
cd 1-backend
docker build -t family-auth-service .
docker run -d --name family-auth --restart unless-stopped family-auth-service
```

### Frontend Deployment (Porkbun)
```powershell
# Deploy all family sites
.\scripts\deploy-family-site.ps1

# Deploy specific family
.\scripts\deploy-family-site.ps1 -Family bull
```

### DNS Configuration
```powershell
# Setup DNS records
.\scripts\setup-dns.ps1 -CreateRecords
```

## 👥 Family Management

### Adding New Families
```powershell
# Add new family structure
.\scripts\add-family.ps1 -Name "johnson"

# Deploy new family
.\scripts\deploy-family-site.ps1 -Family johnson
```

### Family Access Control

Users can be granted access to multiple families:
- **Email verification** determines base access
- **Family-specific permissions** can be configured
- **Marketing consent** is tracked per family

## 📊 Admin Features

### Email Marketing Lists
- **Per-family lists**: Export Bull, North, Klingenberg, Herrman separately
- **Consent tracking**: GDPR-compliant opt-in/opt-out
- **Admin dashboard**: User and family analytics

### Access Control
- **JWT-based sessions**: Secure, stateless authentication  
- **Family context**: Users see only authorized families
- **Admin panel**: User management at `auth.futurelink.zip/admin/`

## 🔧 Development

### Backend Development
```bash
cd 1-backend
pip install -r requirements.txt
python -m uvicorn main:app --reload --port 8000
```

### Frontend Development
- Edit files in `2-family-sites/{family}/`
- Test locally by serving static files
- Deploy with PowerShell scripts

### Adding New Family Sites
1. Create folder in `2-family-sites/{family_name}/`
2. Add family name to `FAMILY_NAMES` in `.env`
3. Run `.\scripts\add-family.ps1 -Name {family_name}`
4. Deploy with `.\scripts\deploy-family-site.ps1`

## 📋 Current Status

- ✅ **Project structure created**
- ✅ **Gladys wiki moved to `/bull` path**
- ✅ **Environment configuration defined**
- ⏳ **FastAPI backend** (in progress)
- ⏳ **Frontend authentication** (planned)
- ⏳ **Porkbun deployment scripts** (planned)
- ⏳ **Oracle VM setup** (planned)

## 📞 Support

- **Documentation**: See individual component READMEs
- **Issues**: Use GitHub Issues for bug reports
- **Deployment help**: Check `scripts/` directory

---

*This platform preserves and shares family histories with modern web technology and security.*