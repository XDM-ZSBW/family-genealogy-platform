# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Common Development Commands

### Environment Setup
```bash path=null start=null
# Create virtual environment
python -m venv venv

# Activate virtual environment (PowerShell on Windows)
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### Development Server
```bash path=null start=null
# Start FastAPI development server with auto-reload
python -m uvicorn main:app --reload --port 8000

# Alternative: run main.py directly (includes uvicorn config)
python main.py
```

### Testing
```bash path=null start=null
# Run all tests
pytest

# Run tests with verbose output
pytest -v

# Run specific test file
pytest test_email.py

# Test email service functionality (sends real email to bcherrman@gmail.com)
python test_email.py

# Test simple SES integration
python simple_ses_test.py
```

### Database Operations
```bash path=null start=null
# Database initialization happens automatically on app startup
# Manual database inspection (SQLite)
sqlite3 family_genealogy.db
```

## High-Level Architecture

### Core Components
This is a **FastAPI authentication service** for a multi-family genealogy platform:

- **`main.py`** - FastAPI app with OAuth flow, email verification, and JWT authentication
- **`auth/google.py`** - Google OAuth 2.0 integration with family-aware state management  
- **`db/models.py`** - SQLModel database models with multi-family access control
- **`email_service/ses_service.py`** - Amazon SES integration with family-specific email templates
- **`families/`** - Family-specific utilities (minimal module)

### Authentication Flow Architecture
1. **Family-Context OAuth** - User visits `/oauth/start` with family parameter (bull, north, etc.)
2. **Google OAuth Exchange** - State parameter encodes family name: `{family}:{csrf_token}`
3. **Email Verification** - SES sends family-branded verification email with 6-digit code
4. **Access Grant** - Verification creates `FamilyAccess` record and sets JWT cookie
5. **Multi-Family Support** - Users can access multiple families, stored in `families` JWT claim

### Database Design
- **Users** - Google OAuth user profiles with verification timestamps
- **FamilyAccess** - Many-to-many relationship between users and families  
- **UserConsent** - GDPR-compliant marketing consent tracking per family
- **EmailVerificationToken** - Temporary tokens with 30-minute expiry
- **AdminSession** - Admin authentication tracking

### Family System
Families are configured via `FAMILY_NAMES` environment variable (default: bull,north,klingenberg,herrman). Each family gets:
- Dedicated email templates in SES service
- Isolated access control  
- Family-specific JWT claims
- Branded verification emails

## Key Configuration

### Required Environment Variables
```bash path=null start=null
# Google OAuth (required)
GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_client_secret

# Amazon SES (required)  
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
SES_REGION=us-east-1
SES_FROM_EMAIL=family@futurelink.zip

# JWT Security (required)
JWT_SECRET=your_long_random_secret

# Application (optional)
DATABASE_URL=sqlite:///./family_genealogy.db
FAMILY_NAMES=bull,north,klingenberg,herrman
CORS_ORIGINS=https://family.futurelink.zip,https://auth.futurelink.zip
BACKEND_BASE=https://auth.futurelink.zip
OAUTH_REDIRECT=https://auth.futurelink.zip/oauth/callback
```

### OAuth Configuration
- **Redirect URI**: Must match `OAUTH_REDIRECT` in Google Console
- **Scopes**: `openid email profile`
- **State Parameter**: Encodes family context as `{family_name}:{csrf_token}`

### SES Email Templates
Family templates are hard-coded in `ses_service.py`:
- **bull**: Bull Family Archives (Gladys Klingenberg focus)
- **north**: North Family Archives  
- **klingenberg**: Klingenberg Family Archives
- **herrman**: Herrman Family Archives

## Development Workflow

### Database Management
- **Auto-initialization**: Database tables created on app startup
- **Schema Changes**: Manual SQLModel migrations (no Alembic setup)
- **Global Manager**: `db_manager` singleton provides database utilities
- **Session Dependency**: Use `get_session()` dependency for route handlers

### Testing Email Service
- **Real Email Test**: `test_email.py` sends actual verification email to bcherrman@gmail.com
- **SES Configuration**: Supports both SMTP and SDK modes via `EMAIL_PROVIDER_MODE`
- **Template Testing**: Each family has distinct email branding and subject prefixes

### JWT Token Management
- **Family Context**: JWT tokens include `families` array claim
- **Expiry**: 24-hour default expiry for user sessions
- **Verification Tokens**: 30-minute expiry for email verification
- **Cookie Security**: `httponly=True, secure=True, samesite="lax"`

### Family Access Control
- Use `is_valid_family(family_name)` to validate family parameters
- Use `get_valid_families()` to get allowed family list
- Family access is granted via `db_manager.grant_family_access()`
- Users can have access to multiple families simultaneously

### OAuth State Security
- State parameter format: `{family_name}:{csrf_token}`
- CSRF protection via `secrets.token_urlsafe(32)`
- State validation in callback extracts family context
- Invalid families rejected at OAuth start

### Development vs Production
- **Debug Mode**: Set `DEBUG=true` to enable `/docs` and `/redoc` endpoints
- **Database Echo**: Set `DATABASE_ECHO=true` for SQL query logging
- **Oracle VM Deployment**: Backend runs on Oracle VM, frontend on Porkbun hosting
- **Docker Deployment**: Uses Google Cloud for Docker (not Oracle per user preference)