# Backend API Development Sync Documentation

**Created**: October 15, 2025  
**Purpose**: Synchronize backend API development (other thread) with frontend authentication system  
**Status**: 🔄 In Development

## 🎯 Current State

### Frontend Authentication System (THIS THREAD - COMPLETED ✅)
- ✅ **auth-check.js** deployed to `https://family.futurelink.zip/auth-check.js`
- ✅ **Family Gateway** deployed to `https://family.futurelink.zip/family/`
- ✅ **Family Sites** configured to redirect for authentication
- ✅ **Development fallback** implemented for API unavailability

### Backend API System (OTHER THREAD - IN PROGRESS 🔄)
- 🔄 **API Domain**: `https://api.futurelink.zip`
- 🔄 **Google OAuth Integration**
- 🔄 **User Session Management**
- 🔄 **Family Access Controls**

## 🔗 API Endpoints Required

The frontend authentication system expects these endpoints to be available:

### 1. Authentication Check Endpoint
```http
GET https://api.futurelink.zip/me
```
**Headers**: 
- `Content-Type: application/json`
- Cookies: Session/auth cookies

**Expected Response (Authenticated)**:
```json
{
  "id": "user123",
  "email": "user@example.com",
  "name": "John Doe",
  "families": ["north", "bull", "klingenberg", "herrman"],
  "authenticated": true
}
```

**Expected Response (Unauthenticated)**:
```http
HTTP/1.1 401 Unauthorized
```

### 2. Login Endpoint
```http
POST https://api.futurelink.zip/login
```
**Purpose**: Initiate Google OAuth flow or handle OAuth callback

### 3. Logout Endpoint  
```http
POST https://api.futurelink.zip/logout
```
**Purpose**: Clear user session and cookies

## 🔐 Google OAuth Configuration

### Required OAuth Settings
- **Authorized JavaScript origins**: 
  - `https://family.futurelink.zip`
  - `https://api.futurelink.zip`
- **Authorized redirect URIs**:
  - `https://api.futurelink.zip/auth/google/callback`
  - `https://family.futurelink.zip/auth/callback`

### Environment Variables Needed
```bash
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here
GOOGLE_REDIRECT_URI=https://api.futurelink.zip/auth/google/callback
```

## 🏛️ Family Access Control Matrix

### Site ID to Family Name Mapping
```javascript
const siteToFamily = {
    'north570525': 'north',
    'bull683912': 'bull', 
    'herrman242585': 'herrman',
    'klingenberg422679': 'klingenberg'
};
```

### User Access Control
Users should have a `families` array indicating which family archives they can access:
```json
{
  "families": ["north", "bull"]  // User can access North and Bull family sites
}
```

## 🌐 CORS Configuration

The API must allow requests from the frontend domain:

```javascript
// CORS Headers Required
Access-Control-Allow-Origin: https://family.futurelink.zip
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

## 🍪 Session Management

### Cookie Requirements
- **Secure**: `true` (HTTPS only)
- **HttpOnly**: `true` (prevent XSS)
- **SameSite**: `'lax'` or `'strict'`
- **Domain**: `.futurelink.zip` (allow subdomain access)

## 🔄 Authentication Flow

### Current Frontend Flow
1. **Family Site Access**: User visits `https://family.futurelink.zip/sites/north570525/`
2. **Auth Check**: `auth-check.js` calls `GET /me` 
3. **Redirect Decision**:
   - ✅ Authenticated + Has Access → Allow access
   - ❌ Unauthenticated → Redirect to `/family/?reason=authentication_required`
   - ❌ No Access → Redirect to `/family/?reason=insufficient_access`
4. **Login Flow**: User clicks "Continue with Google" → Backend handles OAuth
5. **Post-Login**: Redirect back to original family site

### Backend Flow Requirements
1. **OAuth Initiation**: Redirect to Google OAuth
2. **OAuth Callback**: Handle Google response, create session
3. **User Lookup**: Determine family access permissions
4. **Session Storage**: Store user data and family permissions
5. **Redirect**: Send user back to intended family site

## 🚨 Error Handling

### API Unavailable (Network Error)
- **Frontend Behavior**: Shows warning banner, allows temporary access
- **Message**: "API temporarily unavailable. Please contact administrator..."

### Authentication Failed
- **Frontend Behavior**: Redirects to `/family/?reason=auth_error`
- **Message**: "Authentication error occurred. Please try signing in again."

### Insufficient Access
- **Frontend Behavior**: Redirects to `/family/?reason=insufficient_access`
- **Message**: "You don't have access to this family archive..."

## 📋 Testing Checklist

### Backend API Tests Needed
- [ ] **Health Check**: `GET /health` returns 200
- [ ] **CORS**: Preflight OPTIONS requests handled
- [ ] **Session**: Cookie-based session management working
- [ ] **OAuth**: Google OAuth flow completes successfully
- [ ] **User Data**: `/me` endpoint returns correct user + family data
- [ ] **Access Control**: Family access permissions enforced
- [ ] **Logout**: Session clearing works properly

### Integration Tests
- [ ] **Auth Flow**: Complete login flow from family site
- [ ] **Family Access**: Users can only access authorized families
- [ ] **Session Persistence**: Login persists across browser sessions
- [ ] **Logout Flow**: Logout clears session and redirects properly

## 🔧 Development Environment

### Local Development URLs
- **Frontend**: `http://localhost:3000` or file:// protocol
- **Backend**: `http://localhost:8000` (FastAPI default)
- **OAuth Redirect**: Update for local testing

### Production URLs
- **Frontend**: `https://family.futurelink.zip`
- **Backend**: `https://api.futurelink.zip`
- **OAuth Redirect**: Production callback URL

## 📝 Sync Points

### When Backend is Ready
1. **Update auth-check.js**: Remove development fallback mode
2. **Test Integration**: Verify complete auth flow
3. **Deploy Updates**: Push auth-check.js updates to FTP
4. **Update Documentation**: Mark as production-ready

### Communication Protocol
- **Backend Thread Updates**: Document API endpoint changes here
- **Frontend Thread Updates**: Document UI/flow changes here
- **Integration Issues**: Log cross-system compatibility issues

## 🚀 Deployment Coordination

### Backend Deployment Checklist
- [ ] **SSL Certificate**: HTTPS enabled for api.futurelink.zip
- [ ] **DNS Configuration**: api.futurelink.zip resolves correctly
- [ ] **Environment Variables**: All OAuth credentials configured
- [ ] **Database Setup**: User and session storage ready
- [ ] **CORS Configuration**: Frontend domain allowed

### Frontend Updates Needed After Backend Deploy
- [ ] **Remove Development Mode**: Disable family selection fallback
- [ ] **Update Google Client ID**: Add actual client ID to gateway page
- [ ] **Test Production Flow**: Verify end-to-end authentication
- [ ] **Update Error Messages**: Production-appropriate messaging

---

## 📞 Inter-Thread Communication

**To sync with this document:**
1. Update relevant sections as backend development progresses
2. Note any API endpoint changes or additions needed
3. Document any integration issues discovered during development
4. Mark items as complete ✅ when tested and working

**Last Updated**: October 15, 2025  
**Next Sync**: When backend API endpoints are available for testing