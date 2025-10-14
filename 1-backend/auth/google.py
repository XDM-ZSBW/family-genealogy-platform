"""
Google OAuth authentication service for Family Genealogy Platform
Handles Google OAuth 2.0 flow with family context awareness
"""

import os
import secrets
import jwt
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
import httpx
import logging

logger = logging.getLogger(__name__)


class GoogleAuthService:
    """Google OAuth 2.0 authentication service"""
    
    def __init__(self):
        self.client_id = os.getenv("GOOGLE_CLIENT_ID")
        self.client_secret = os.getenv("GOOGLE_CLIENT_SECRET") 
        self.redirect_uri = os.getenv("OAUTH_REDIRECT", "https://auth.futurelink.zip/oauth2callback")
        self.jwt_secret = os.getenv("JWT_SECRET")
        
        if not self.client_id or not self.client_secret:
            raise ValueError("Google OAuth credentials not configured")
        if not self.jwt_secret:
            raise ValueError("JWT secret not configured")
    
    def get_authorization_url(self, family_name: str, state: str = None) -> str:
        """
        Generate Google OAuth authorization URL with family context
        
        Args:
            family_name: Family name (bull, north, etc.)
            state: Optional state parameter for CSRF protection
            
        Returns:
            Authorization URL
        """
        if not state:
            state = secrets.token_urlsafe(32)
        
        # Encode family name in state parameter
        family_state = f"{family_name}:{state}"
        
        params = {
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
            "scope": "openid email profile",
            "response_type": "code",
            "access_type": "offline",
            "prompt": "consent",
            "state": family_state
        }
        
        # Build query string
        query_string = "&".join([f"{k}={v}" for k, v in params.items()])
        auth_url = f"https://accounts.google.com/o/oauth2/v2/auth?{query_string}"
        
        logger.info(f"Generated OAuth URL for family: {family_name}")
        return auth_url
    
    async def exchange_code_for_tokens(self, code: str, state: str) -> Dict[str, Any]:
        """
        Exchange authorization code for tokens
        
        Args:
            code: Authorization code from Google
            state: State parameter containing family info
            
        Returns:
            Dict with tokens and user info
        """
        try:
            # Parse family name from state
            family_name, original_state = state.split(":", 1) if ":" in state else (None, state)
            
            # Exchange code for tokens
            token_data = {
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": self.redirect_uri
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://oauth2.googleapis.com/token",
                    data=token_data,
                    headers={"Content-Type": "application/x-www-form-urlencoded"}
                )
                response.raise_for_status()
                tokens = response.json()
            
            # Verify and decode ID token
            id_token_jwt = tokens.get("id_token")
            if not id_token_jwt:
                raise ValueError("No ID token in response")
            
            # Verify the ID token
            idinfo = id_token.verify_oauth2_token(
                id_token_jwt, 
                google_requests.Request(), 
                self.client_id
            )
            
            # Extract user information
            user_info = {
                "google_id": idinfo.get("sub"),
                "email": idinfo.get("email"),
                "name": idinfo.get("name"),
                "picture": idinfo.get("picture"),
                "email_verified": idinfo.get("email_verified", False)
            }
            
            logger.info(f"OAuth exchange successful for {user_info['email']} (family: {family_name})")
            
            return {
                "success": True,
                "tokens": tokens,
                "user_info": user_info,
                "family_name": family_name,
                "state": original_state
            }
            
        except Exception as e:
            logger.error(f"OAuth token exchange failed: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def create_jwt_token(self, user_id: int, email: str, families: list = None, 
                        expires_hours: int = 24) -> str:
        """
        Create JWT token for authenticated user
        
        Args:
            user_id: User database ID
            email: User email address
            families: List of family names user has access to
            expires_hours: Token expiration in hours
            
        Returns:
            JWT token string
        """
        now = datetime.now(timezone.utc)
        expire = now + timedelta(hours=expires_hours)
        
        payload = {
            "user_id": user_id,
            "email": email,
            "families": families or [],
            "iat": now,
            "exp": expire,
            "iss": "family-genealogy-platform",
            "sub": str(user_id)
        }
        
        token = jwt.encode(payload, self.jwt_secret, algorithm="HS256")
        return token
    
    def verify_jwt_token(self, token: str) -> Optional[Dict[str, Any]]:
        """
        Verify and decode JWT token
        
        Args:
            token: JWT token string
            
        Returns:
            Decoded token payload or None if invalid
        """
        try:
            payload = jwt.decode(token, self.jwt_secret, algorithms=["HS256"])
            
            # Check if token is expired
            exp = payload.get("exp")
            if exp and datetime.fromtimestamp(exp, timezone.utc) < datetime.now(timezone.utc):
                logger.warning("JWT token expired")
                return None
            
            return payload
            
        except jwt.ExpiredSignatureError:
            logger.warning("JWT token expired")
            return None
        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid JWT token: {str(e)}")
            return None
    
    def create_verification_token(self, email: str, family_name: str, user_id: int = None) -> str:
        """
        Create signed verification token for email verification
        
        Args:
            email: Email address to verify
            family_name: Family context
            user_id: Optional user ID if user exists
            
        Returns:
            Signed verification token
        """
        now = datetime.now(timezone.utc)
        expire = now + timedelta(minutes=30)  # 30 minute expiry
        
        payload = {
            "email": email,
            "family_name": family_name,
            "user_id": user_id,
            "type": "email_verification",
            "iat": now,
            "exp": expire,
            "iss": "family-genealogy-platform"
        }
        
        token = jwt.encode(payload, self.jwt_secret, algorithm="HS256")
        return token
    
    def verify_verification_token(self, token: str) -> Optional[Dict[str, Any]]:
        """
        Verify email verification token
        
        Args:
            token: Verification token
            
        Returns:
            Decoded token payload or None if invalid
        """
        try:
            payload = jwt.decode(token, self.jwt_secret, algorithms=["HS256"])
            
            # Check token type
            if payload.get("type") != "email_verification":
                logger.warning("Invalid verification token type")
                return None
            
            return payload
            
        except jwt.ExpiredSignatureError:
            logger.warning("Verification token expired")
            return None
        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid verification token: {str(e)}")
            return None


# Global instance
google_auth = GoogleAuthService()


def get_google_auth() -> GoogleAuthService:
    """Get Google auth service instance"""
    return google_auth