"""
Database models for the Family Genealogy Platform
"""

from datetime import datetime, timezone
from typing import Optional, List
from sqlmodel import SQLModel, Field, Relationship, create_engine, Session
from pydantic import EmailStr
import os


class User(SQLModel, table=True):
    """User account information"""
    __tablename__ = "users"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    email: EmailStr = Field(unique=True, index=True)
    google_id: str = Field(unique=True, index=True)
    name: str
    picture_url: Optional[str] = None
    verified_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    last_login: Optional[datetime] = None
    is_active: bool = Field(default=True)
    
    # Relationships
    family_access: List["FamilyAccess"] = Relationship(back_populates="user")
    consent_records: List["UserConsent"] = Relationship(back_populates="user")


class FamilyAccess(SQLModel, table=True):
    """Which families a user has access to"""
    __tablename__ = "family_access"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    family_name: str = Field(index=True)  # bull, north, klingenberg, herrman
    granted_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    granted_by: str = Field(default="email_verification")  # email_verification, admin, invite
    is_active: bool = Field(default=True)
    
    # Relationships
    user: User = Relationship(back_populates="family_access")


class UserConsent(SQLModel, table=True):
    """Marketing consent tracking per family"""
    __tablename__ = "user_consent"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.id")
    family_name: str = Field(index=True)
    marketing_consent: bool = Field(default=False)
    terms_accepted: bool = Field(default=False)
    consent_version: str = Field(default="1.0")
    consented_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    
    # Relationships
    user: User = Relationship(back_populates="consent_records")


class EmailVerificationToken(SQLModel, table=True):
    """Temporary tokens for email verification"""
    __tablename__ = "email_verification_tokens"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    token: str = Field(unique=True, index=True)
    email: EmailStr
    family_name: str
    verification_code: str  # 6-digit code sent via email
    user_id: Optional[int] = Field(default=None, foreign_key="users.id")
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    expires_at: datetime
    verified_at: Optional[datetime] = None
    attempts: int = Field(default=0)
    is_used: bool = Field(default=False)


class FamilyInvitationCode(SQLModel, table=True):
    """Family invitation codes for sharing access"""
    __tablename__ = "family_invitation_codes"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    code: str = Field(unique=True, index=True)  # 8-character shareable code
    family_name: str = Field(index=True)
    created_by_user_id: int = Field(foreign_key="users.id")
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    expires_at: Optional[datetime] = None  # None = never expires
    max_uses: Optional[int] = None  # None = unlimited uses
    current_uses: int = Field(default=0)
    is_active: bool = Field(default=True)
    description: Optional[str] = None  # e.g., "Bull Family - Grandma's Stories"


class AdminSession(SQLModel, table=True):
    """Admin session tracking"""
    __tablename__ = "admin_sessions"
    
    id: Optional[int] = Field(default=None, primary_key=True)
    session_token: str = Field(unique=True, index=True)
    admin_email: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    expires_at: datetime
    last_activity: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    ip_address: Optional[str] = None
    is_active: bool = Field(default=True)


# Database configuration
def get_database_url() -> str:
    """Get database URL from environment or use default"""
    return os.getenv("DATABASE_URL", "sqlite:///./family_genealogy.db")


def create_db_engine():
    """Create database engine"""
    database_url = get_database_url()
    
    # SQLite specific settings
    if database_url.startswith("sqlite"):
        from sqlalchemy import event
        engine = create_engine(
            database_url,
            echo=os.getenv("DATABASE_ECHO", "false").lower() == "true",
            connect_args={"check_same_thread": False}  # SQLite specific
        )
        
        # Enable foreign keys for SQLite
        def _fk_pragma_on_connect(dbapi_con, con_record):
            dbapi_con.execute('pragma foreign_keys=ON')
        
        event.listen(engine, 'connect', _fk_pragma_on_connect)
        
    else:
        engine = create_engine(
            database_url,
            echo=os.getenv("DATABASE_ECHO", "false").lower() == "true"
        )
    
    return engine


def init_db():
    """Initialize database tables"""
    engine = create_db_engine()
    SQLModel.metadata.create_all(engine)
    return engine


def get_session():
    """Get database session"""
    engine = create_db_engine()
    with Session(engine) as session:
        yield session


# Family configuration
def get_valid_families() -> List[str]:
    """Get list of valid family names from environment"""
    family_names = os.getenv("FAMILY_NAMES", "bull,north,klingenberg,herrman")
    return [name.strip() for name in family_names.split(",")]


def is_valid_family(family_name: str) -> bool:
    """Check if family name is valid"""
    return family_name in get_valid_families()


# Utility functions
class DatabaseManager:
    """Database management utilities"""
    
    def __init__(self):
        self.engine = None
    
    def init_database(self):
        """Initialize the database"""
        self.engine = init_db()
        return self.engine
    
    def get_user_by_email(self, email: str) -> Optional[User]:
        """Get user by email address"""
        with Session(self.engine) as session:
            return session.query(User).filter(User.email == email).first()
    
    def get_user_by_google_id(self, google_id: str) -> Optional[User]:
        """Get user by Google ID"""
        with Session(self.engine) as session:
            return session.query(User).filter(User.google_id == google_id).first()
    
    def create_user(self, email: str, google_id: str, name: str, picture_url: str = None) -> User:
        """Create new user"""
        user = User(
            email=email,
            google_id=google_id,
            name=name,
            picture_url=picture_url
        )
        
        with Session(self.engine) as session:
            session.add(user)
            session.commit()
            session.refresh(user)
            return user
    
    def grant_family_access(self, user_id: int, family_name: str, granted_by: str = "email_verification") -> FamilyAccess:
        """Grant user access to a family"""
        access = FamilyAccess(
            user_id=user_id,
            family_name=family_name,
            granted_by=granted_by
        )
        
        with Session(self.engine) as session:
            session.add(access)
            session.commit()
            session.refresh(access)
            return access
    
    def get_user_families(self, user_id: int) -> List[str]:
        """Get list of families user has access to"""
        with Session(self.engine) as session:
            access_records = session.query(FamilyAccess).filter(
                FamilyAccess.user_id == user_id,
                FamilyAccess.is_active == True
            ).all()
            return [record.family_name for record in access_records]
    
    def record_consent(self, user_id: int, family_name: str, marketing_consent: bool, 
                      terms_accepted: bool, ip_address: str = None, user_agent: str = None) -> UserConsent:
        """Record user consent for marketing and terms"""
        consent = UserConsent(
            user_id=user_id,
            family_name=family_name,
            marketing_consent=marketing_consent,
            terms_accepted=terms_accepted,
            ip_address=ip_address,
            user_agent=user_agent
        )
        
        with Session(self.engine) as session:
            session.add(consent)
            session.commit()
            session.refresh(consent)
            return consent
    
    def create_invitation_code(self, user_id: int, family_name: str, description: str = None, 
                              max_uses: int = None, expires_days: int = None) -> str:
        """Create a new family invitation code with family prefix (e.g., north_ABC123XY)"""
        import secrets
        import string
        
        # Generate 8-character code (uppercase letters and numbers)
        random_part = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8))
        
        # Create family-prefixed code (e.g., northABC123XY)
        full_code = f"{family_name.lower()}{random_part}"
        
        # Calculate expiry if specified
        expires_at = None
        if expires_days:
            from datetime import timedelta
            expires_at = datetime.now(timezone.utc) + timedelta(days=expires_days)
        
        invitation = FamilyInvitationCode(
            code=full_code,
            family_name=family_name,
            created_by_user_id=user_id,
            description=description,
            max_uses=max_uses,
            expires_at=expires_at
        )
        
        with Session(self.engine) as session:
            session.add(invitation)
            session.commit()
            session.refresh(invitation)
            return full_code
    
    def get_invitation_code(self, code: str):
        """Get invitation code details"""
        with Session(self.engine) as session:
            return session.query(FamilyInvitationCode).filter(
                FamilyInvitationCode.code == code,
                FamilyInvitationCode.is_active == True
            ).first()
    
    def use_invitation_code(self, code: str, user_id: int) -> bool:
        """Use an invitation code to grant family access"""
        with Session(self.engine) as session:
            invitation = session.query(FamilyInvitationCode).filter(
                FamilyInvitationCode.code == code,
                FamilyInvitationCode.is_active == True
            ).first()
            
            if not invitation:
                return False
            
            # Check if code is expired
            if invitation.expires_at and invitation.expires_at < datetime.now(timezone.utc):
                return False
            
            # Check if max uses exceeded
            if invitation.max_uses and invitation.current_uses >= invitation.max_uses:
                return False
            
            # Grant family access
            self.grant_family_access(user_id, invitation.family_name, granted_by=f"invitation_{code}")
            
            # Increment usage count
            invitation.current_uses += 1
            session.add(invitation)
            session.commit()
            
            return True
    
    def get_user_invitation_codes(self, user_id: int):
        """Get all invitation codes created by a user"""
        with Session(self.engine) as session:
            return session.query(FamilyInvitationCode).filter(
                FamilyInvitationCode.created_by_user_id == user_id,
                FamilyInvitationCode.is_active == True
            ).all()


# Global database manager instance
db_manager = DatabaseManager()