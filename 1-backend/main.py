"""
Family Genealogy Platform - FastAPI Backend
Multi-family authentication and access control service
"""

import os
import secrets
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, List
from fastapi import FastAPI, HTTPException, Depends, Query, Cookie, Request, Response
from fastapi.responses import RedirectResponse, JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from sqlmodel import Session

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

# Import our modules
from db.models import init_db, get_session, db_manager, is_valid_family, get_valid_families, FamilyInvitationCode
from auth.google import get_google_auth, GoogleAuthService
from email_service.ses_service import get_family_email_service

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Family Genealogy Platform API",
    description="Multi-family genealogy platform with OAuth authentication and email verification",
    version="1.0.0",
    docs_url="/docs" if os.getenv("DEBUG", "false").lower() == "true" else None,
    redoc_url="/redoc" if os.getenv("DEBUG", "false").lower() == "true" else None
)

# Mount static files if directory exists
try:
    app.mount("/static", StaticFiles(directory="static"), name="static")
except:
    pass  # Static directory may not exist in production

# CORS configuration
cors_origins = os.getenv("CORS_ORIGINS", "https://family.futurelink.zip,https://api.futurelink.zip").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Initialize database on startup
@app.on_event("startup")
async def startup():
    """Initialize database and services"""
    try:
        db_manager.init_database()
        logger.info("Database initialized successfully")
        logger.info(f"Valid families: {get_valid_families()}")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise


# Pydantic models
class InitialSignupRequest(BaseModel):
    email: str

class CreateFamilyRequest(BaseModel):
    family_name: str
    description: str = None

class JoinFamilyRequest(BaseModel):
    invitation_code: str

class VerifyEmailRequest(BaseModel):
    token: str

class ConsentRequest(BaseModel):
    marketing_consent: bool
    terms_accepted: bool

class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    families: List[str]
    verified_at: Optional[datetime]


# Authentication dependency
async def get_current_user(authorization: Optional[str] = Cookie(None)) -> Optional[Dict]:
    """Get current authenticated user from JWT cookie"""
    if not authorization:
        return None
    
    # Handle Bearer token format
    token = authorization
    if authorization.startswith("Bearer "):
        token = authorization[7:]
    
    google_auth = get_google_auth()
    payload = google_auth.verify_jwt_token(token)
    
    if not payload:
        return None
    
    return payload


# Routes
@app.get("/")
async def root():
    """API root endpoint"""
    return {
        "message": "Family Genealogy Platform API",
        "version": "1.0.0",
        "families": get_valid_families(),
        "endpoints": {
            "oauth_start": "/oauth/start",
            "oauth_callback": "/oauth/callback", 
            "verify": "/verify/{token}",
            "me": "/me",
            "families": "/families"
        }
    }


@app.get("/families")
async def list_families():
    """List all available family sites"""
    families = get_valid_families()
    
    family_info = {}
    email_service = get_family_email_service()
    
    for family in families:
        template_info = email_service.family_templates.get(family, {})
        family_info[family] = {
            "name": family,
            "display_name": template_info.get("family_display", f"{family.title()} Family"),
            "description": template_info.get("description", f"{family.title()} family genealogy"),
            "url": f"https://family.futurelink.zip/{family}"
        }
    
    return {
        "families": family_info,
        "total": len(families)
    }


@app.post("/signup/start")
async def start_signup(request: InitialSignupRequest):
    """Start signup process - initiate Google OAuth"""
    google_auth = get_google_auth()
    state = secrets.token_urlsafe(32)
    
    # Store email in state for later use
    auth_state = f"signup:{request.email}:{state}"
    auth_url = google_auth.get_authorization_url("signup", auth_state)
    
    return {
        "auth_url": auth_url,
        "email": request.email,
        "state": auth_state
    }

@app.post("/signup/create-family")
async def create_family_code(request: CreateFamilyRequest, user: Optional[Dict] = Depends(get_current_user)):
    """Create new family and invitation code (for first-time users)"""
    if not user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    # Validate family name
    family_name = request.family_name.lower().strip()
    if not family_name or len(family_name) < 2:
        raise HTTPException(status_code=400, detail="Family name must be at least 2 characters")
    
    # Get user from database
    db_user = db_manager.get_user_by_email(user["email"])
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Create invitation code
    invitation_code = db_manager.create_invitation_code(
        user_id=db_user.id,
        family_name=family_name,
        description=request.description or f"{family_name.title()} Family"
    )
    
    # Grant access to creator
    db_manager.grant_family_access(db_user.id, family_name, granted_by="family_creator")
    
    # Create magic login link
    google_auth = get_google_auth()
    magic_token = google_auth.create_verification_token(
        user["email"],
        family_name,
        db_user.id
    )
    magic_link = f"{os.getenv('BACKEND_BASE', 'https://api.futurelink.zip')}/magic/{magic_token}"
    
    # Send magic link via email
    email_service = get_family_email_service()
    email_result = email_service.send_family_magic_link(
        email=user["email"],
        family_name=family_name,
        invitation_code=invitation_code,
        magic_link=magic_link,
        description=request.description
    )
    
    return {
        "message": "Family created successfully",
        "family_name": family_name,
        "invitation_code": invitation_code,
        "email_sent": email_result.get("success", False)
    }

@app.post("/signup/join-family")
async def join_family_with_code(request: JoinFamilyRequest, user: Optional[Dict] = Depends(get_current_user)):
    """Join family using invitation code"""
    if not user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    # Get user from database
    db_user = db_manager.get_user_by_email(user["email"])
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Use invitation code
    success = db_manager.use_invitation_code(request.invitation_code, db_user.id)
    
    if not success:
        raise HTTPException(status_code=400, detail="Invalid or expired invitation code")
    
    # Get invitation details
    invitation = db_manager.get_invitation_code(request.invitation_code)
    
    # Create magic link for the new family member
    google_auth = get_google_auth()
    magic_token = google_auth.create_verification_token(
        user["email"],
        invitation.family_name,
        db_user.id
    )
    magic_link = f"{os.getenv('BACKEND_BASE', 'https://api.futurelink.zip')}/magic/{magic_token}"
    
    return {
        "message": "Successfully joined family",
        "family_name": invitation.family_name,
        "invitation_code": request.invitation_code,
        "magic_link": magic_link
    }


@app.get("/oauth/callback")
async def oauth_callback(
    code: str = Query(..., description="OAuth authorization code"),
    state: str = Query(..., description="OAuth state parameter"),
    session: Session = Depends(get_session)
):
    """Handle OAuth callback for signup flow"""
    try:
        google_auth = get_google_auth()
        
        # Exchange code for tokens and user info
        result = await google_auth.exchange_code_for_tokens(code, state)
        
        if not result["success"]:
            raise HTTPException(status_code=400, detail=f"OAuth exchange failed: {result.get('error')}")
        
        user_info = result["user_info"]
        signup_info = result["family_name"]  # This contains "signup:{email}:{token}"
        
        if not user_info["email_verified"]:
            raise HTTPException(status_code=400, detail="Google email not verified")
        
        # Parse signup info
        if not signup_info.startswith("signup:"):
            raise HTTPException(status_code=400, detail="Invalid signup state")
        
        _, original_email, _ = signup_info.split(":", 2)
        
        # Verify email matches
        if user_info["email"] != original_email:
            raise HTTPException(status_code=400, detail="Email mismatch")
        
        # Check if user exists
        user = db_manager.get_user_by_email(user_info["email"])
        
        if not user:
            # Create new user
            user = db_manager.create_user(
                email=user_info["email"],
                google_id=user_info["google_id"],
                name=user_info["name"],
                picture_url=user_info.get("picture")
            )
            logger.info(f"Created new user: {user.email}")
        
        # Mark user as verified
        user.verified_at = datetime.now(timezone.utc)
        user.last_login = datetime.now(timezone.utc)
        session.add(user)
        session.commit()
        
        # Create JWT token
        user_families = db_manager.get_user_families(user.id)
        jwt_token = google_auth.create_jwt_token(user.id, user.email, user_families)
        
        # Set JWT cookie and redirect to family selection page
        if user_families:
            # User has families, redirect to main family page
            primary_family = user_families[0]
            redirect_url = f"https://family.futurelink.zip/families/{primary_family}"
        else:
            # New user, redirect to family selection
            redirect_url = f"https://family.futurelink.zip/select-family"
        
        response = RedirectResponse(url=redirect_url)
        response.set_cookie(
            key="authorization",
            value=f"Bearer {jwt_token}",
            max_age=24*60*60,  # 24 hours
            httponly=True,
            secure=True,
            samesite="lax"
        )
        
        return response
        
    except Exception as e:
        logger.error(f"OAuth callback error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/magic/{token}")
async def magic_login(token: str, session: Session = Depends(get_session)):
    """Magic link login - one-click access to family archives"""
    try:
        google_auth = get_google_auth()
        
        # Verify magic token
        payload = google_auth.verify_verification_token(token)
        if not payload:
            raise HTTPException(status_code=400, detail="Invalid or expired magic link")
        
        email = payload["email"]
        family_name = payload["family_name"]
        user_id = payload.get("user_id")
        
        # Get user
        user = db_manager.get_user_by_email(email)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Mark user as verified and update login time
        user.verified_at = datetime.now(timezone.utc)
        user.last_login = datetime.now(timezone.utc)
        session.add(user)
        
        # Grant family access if not already granted
        user_families = db_manager.get_user_families(user.id)
        if family_name not in user_families:
            db_manager.grant_family_access(user.id, family_name, granted_by="magic_link")
            user_families.append(family_name)
        
        # Create JWT token with all user's families
        jwt_token = google_auth.create_jwt_token(user.id, email, user_families)
        
        session.commit()
        
        logger.info(f"Magic link login successful: {email} -> {family_name}")
        
        # Set JWT cookie and redirect directly to family archives
        response = RedirectResponse(url=f"https://family.futurelink.zip/families/{family_name}")
        response.set_cookie(
            key="authorization",
            value=f"Bearer {jwt_token}",
            max_age=24*60*60,  # 24 hours
            httponly=True,
            secure=True,
            samesite="lax"
        )
        
        return response
        
    except Exception as e:
        logger.error(f"Magic link login error: {e}")
        # Redirect to error page instead of raising exception
        return RedirectResponse(url=f"https://family.futurelink.zip/error?message=Invalid+or+expired+link")

@app.get("/verify/{token}")
async def verify_email(token: str, session: Session = Depends(get_session)):
    """Verify email and grant family access"""
    try:
        google_auth = get_google_auth()
        
        # Verify token
        payload = google_auth.verify_verification_token(token)
        if not payload:
            raise HTTPException(status_code=400, detail="Invalid or expired verification token")
        
        email = payload["email"]
        family_name = payload["family_name"]
        user_id = payload.get("user_id")
        
        # Get user
        user = db_manager.get_user_by_email(email)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Mark user as verified
        user.verified_at = datetime.now(timezone.utc)
        user.last_login = datetime.now(timezone.utc)
        session.add(user)
        
        # Grant family access
        db_manager.grant_family_access(user.id, family_name)
        
        # Get all families user has access to
        user_families = db_manager.get_user_families(user.id)
        
        # Create JWT token
        jwt_token = google_auth.create_jwt_token(user.id, email, user_families)
        
        session.commit()
        
        logger.info(f"Email verified and access granted: {email} -> {family_name}")
        
        # Set JWT cookie and redirect to family site
        response = RedirectResponse(url=f"https://family.futurelink.zip/{family_name}")
        response.set_cookie(
            key="authorization",
            value=f"Bearer {jwt_token}",
            max_age=24*60*60,  # 24 hours
            httponly=True,
            secure=True,
            samesite="lax"
        )
        
        return response
        
    except Exception as e:
        logger.error(f"Email verification error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/me")
async def get_current_user_info(user: Optional[Dict] = Depends(get_current_user)):
    """Get current user information"""
    if not user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    # Get fresh user data from database
    db_user = db_manager.get_user_by_email(user["email"])
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    user_families = db_manager.get_user_families(db_user.id)
    
    return {
        "id": db_user.id,
        "email": db_user.email,
        "name": db_user.name,
        "picture_url": db_user.picture_url,
        "families": user_families,
        "verified_at": db_user.verified_at,
        "created_at": db_user.created_at,
        "last_login": db_user.last_login
    }


@app.post("/consent/{family}")
async def record_consent(
    family: str,
    consent: ConsentRequest,
    request: Request,
    user: Optional[Dict] = Depends(get_current_user)
):
    """Record user consent for marketing and terms"""
    if not user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    if not is_valid_family(family):
        raise HTTPException(status_code=400, detail="Invalid family name")
    
    # Record consent
    db_manager.record_consent(
        user_id=user["user_id"],
        family_name=family,
        marketing_consent=consent.marketing_consent,
        terms_accepted=consent.terms_accepted,
        ip_address=request.client.host,
        user_agent=request.headers.get("user-agent")
    )
    
    return {
        "message": "Consent recorded",
        "family": family,
        "marketing_consent": consent.marketing_consent,
        "terms_accepted": consent.terms_accepted
    }


# Admin endpoints (protected by ADMIN_TOKEN)
@app.get("/admin/emails/{family}.csv")
async def export_family_emails(
    family: str,
    admin_token: str = Query(..., description="Admin authentication token")
):
    """Export marketing emails for specific family (CSV format)"""
    expected_token = os.getenv("ADMIN_TOKEN")
    if not expected_token or admin_token != expected_token:
        raise HTTPException(status_code=401, detail="Invalid admin token")
    
    if not is_valid_family(family):
        raise HTTPException(status_code=400, detail="Invalid family name")
    
    # This would be implemented to query the database and return CSV
    # For now, return placeholder
    return {
        "message": f"Email export for {family} family",
        "family": family,
        "note": "CSV export functionality to be implemented"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc),
        "database": "connected",
        "families": get_valid_families()
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="127.0.0.1",
        port=8000,
        reload=True,
        log_level="info"
    )