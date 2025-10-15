# Google OAuth Setup Guide for Family Genealogy Platform

## 🎯 Quick Setup Instructions

### Step 1: OAuth Consent Screen
1. Visit: https://console.cloud.google.com/apis/credentials/consent?project=futurelink-private-112912460
2. Configure these settings:
   - **App Name**: `FutureLink Family Genealogy Platform`  
   - **User Support Email**: Your email address
   - **App Domain**: `https://family.futurelink.zip`
   - **Authorized Domains**: `futurelink.zip`
   - **Developer Contact**: Your email address

### Step 2: Create OAuth 2.0 Client ID
1. Visit: https://console.cloud.google.com/apis/credentials?project=futurelink-private-112912460
2. Click **"+ CREATE CREDENTIALS"** → **"OAuth 2.0 Client ID"**
3. Configure:
   - **Application Type**: Web application
   - **Name**: `family-genealogy-web-client`

#### Authorized JavaScript Origins:
```
https://family.futurelink.zip
https://api.futurelink.zip
http://localhost:3000
http://localhost:8000
```

#### Authorized Redirect URIs:
```
https://api.futurelink.zip/auth/google/callback
https://family.futurelink.zip/auth/callback  
http://localhost:8000/auth/google/callback
http://localhost:3000/auth/callback
```

### Step 3: Copy Credentials
After creating the OAuth client, copy the **Client ID** and **Client Secret**.

## 🔧 CLI Commands for Quick Setup

### Enable Required APIs:
```powershell
gcloud services enable iam.googleapis.com --project=futurelink-private-112912460
gcloud services enable iamcredentials.googleapis.com --project=futurelink-private-112912460
```

### Check Current Project:
```powershell
gcloud config get-value project
```

### List Existing OAuth Clients:
```powershell
gcloud alpha iap oauth-clients list
```

## 📝 Environment Variables Template

Copy your OAuth credentials to `.env` file:

```bash
# Google OAuth Configuration
GOOGLE_CLIENT_ID=your_client_id_here.apps.googleusercontent.com  
GOOGLE_CLIENT_SECRET=your_client_secret_here

# OAuth Settings
GOOGLE_REDIRECT_URI=https://api.futurelink.zip/auth/google/callback
GOOGLE_SCOPE=openid email profile

# Session Configuration
SESSION_SECRET=$(openssl rand -hex 32)  # Generate a secure secret
SESSION_COOKIE_DOMAIN=.futurelink.zip
SESSION_COOKIE_SECURE=true
SESSION_COOKIE_HTTPONLY=true

# API URLs
API_BASE_URL=https://api.futurelink.zip
FRONTEND_URL=https://family.futurelink.zip

# Family Access Control (comma-separated emails)
NORTH_FAMILY_ACCESS=user1@example.com,user2@example.com
BULL_FAMILY_ACCESS=user1@example.com  
HERRMAN_FAMILY_ACCESS=user2@example.com
KLINGENBERG_FAMILY_ACCESS=user1@example.com,user2@example.com
```

## 🧪 Test OAuth Configuration

After setting up OAuth credentials, test with:

```powershell
.\test-oauth.ps1 -ClientId "your_client_id" -ClientSecret "your_client_secret"
```

## 🔗 Integration Points

### Frontend (Already Deployed ✅)
- **auth-check.js**: `https://family.futurelink.zip/auth-check.js`
- **Family Gateway**: `https://family.futurelink.zip/family/`
- **North Family Site**: `https://family.futurelink.zip/sites/north570525/`

### Backend API (Needs OAuth Integration 🔄)
The backend API should implement these endpoints:

```http
GET  /me                    # Check authentication status
POST /auth/google          # Initiate Google OAuth
GET  /auth/google/callback # Handle OAuth callback  
POST /logout              # Clear session
```

### Authentication Flow
1. User visits family site → `auth-check.js` runs
2. If not authenticated → Redirect to `/family/`  
3. User clicks "Continue with Google" → Backend handles OAuth
4. After successful login → Redirect back to family site
5. `auth-check.js` verifies session → Allow access

## 🚀 Testing URLs

### Manual Test Sequence:
1. Visit: https://family.futurelink.zip/sites/north570525/
2. Should redirect to: https://family.futurelink.zip/family/
3. Click "Continue with Google"
4. Complete OAuth flow
5. Should redirect back to North family site

### OAuth Test URL (replace CLIENT_ID):
```
https://accounts.google.com/o/oauth2/v2/auth?client_id=CLIENT_ID&response_type=code&scope=openid%20email%20profile&redirect_uri=https://api.futurelink.zip/auth/google/callback&state=test
```

## 🔐 Security Configuration

### Required Cookie Settings:
```javascript
{
  secure: true,        // HTTPS only
  httpOnly: true,      // Prevent XSS
  sameSite: 'lax',     // CSRF protection
  domain: '.futurelink.zip',  // Allow subdomains
  maxAge: 24 * 60 * 60 * 1000  // 24 hours
}
```

### CORS Settings for API:
```javascript
{
  origin: 'https://family.futurelink.zip',
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}
```

---

**Project**: `futurelink-private-112912460`  
**Status**: OAuth configuration ready for manual setup  
**Next**: Implement backend API OAuth integration