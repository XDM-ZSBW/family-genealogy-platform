#!/usr/bin/env python3
"""
Test script to send SES verification email
This will test the email functionality by sending to bcherrman@gmail.com
"""

import os
import sys
from pathlib import Path

# Add the backend directory to Python path
backend_dir = Path(__file__).parent
sys.path.insert(0, str(backend_dir))

# Load environment variables from .env file
from dotenv import load_dotenv

# Try multiple possible .env locations
env_locations = [
    Path(__file__).parent / ".env",          # Same directory as script
    Path(__file__).parent.parent / ".env",   # Parent directory
    Path.cwd() / ".env"                     # Current working directory
]

env_loaded = False
for env_path in env_locations:
    if env_path.exists():
        load_dotenv(env_path)
        print(f"✓ Loaded environment variables from {env_path}")
        env_loaded = True
        break

if not env_loaded:
    print("⚠️ No .env file found in any expected location")
    print("   Checked:")
    for path in env_locations:
        print(f"     - {path}")
    print("   Using system environment variables only")

# Import our email service
from email_service.ses_service import get_family_email_service

def test_email_service():
    """Test sending verification email to bcherrman@gmail.com"""
    
    print("\n🧪 Testing Family Email Service")
    print("="*50)
    
    try:
        # Initialize email service
        email_service = get_family_email_service()
        print("✓ Email service initialized")
        
        # Test configuration
        config = email_service.get_ses_config()
        print(f"✓ SES configuration loaded:")
        print(f"  - Region: {config.region}")
        print(f"  - From email: {config.from_email}")
        print(f"  - Mode: {config.mode.value}")
        
        # Test email details
        test_email = "bcherrman@gmail.com"
        family_name = "bull"  # Testing with Bull family (Gladys)
        verification_code = email_service.generate_verification_code()
        verification_link = f"https://auth.futurelink.zip/verify/test-token-{verification_code}"
        
        print(f"\n📧 Sending test verification email:")
        print(f"  - To: {test_email}")
        print(f"  - Family: {family_name}")
        print(f"  - Code: {verification_code}")
        print(f"  - Link: {verification_link}")
        
        # Send the email
        result = email_service.send_family_verification_email(
            email=test_email,
            family_name=family_name,
            verification_code=verification_code,
            verification_link=verification_link
        )
        
        if result["success"]:
            print(f"\n✅ EMAIL SENT SUCCESSFULLY!")
            print(f"  - Message ID: {result['message_id']}")
            print(f"  - Family: {result['family']}")
            print(f"\n📬 Check {test_email} for the verification email.")
            print(f"   Subject should start with: [Bull Family Archives]")
            return True
        else:
            print(f"\n❌ EMAIL FAILED TO SEND!")
            print(f"  - Error: {result['error']}")
            print(f"  - Message: {result['message']}")
            return False
            
    except Exception as e:
        print(f"\n💥 UNEXPECTED ERROR!")
        print(f"  - Error: {str(e)}")
        return False

def test_family_templates():
    """Test family template information"""
    print("\n👨‍👩‍👧‍👦 Testing Family Templates")
    print("="*50)
    
    email_service = get_family_email_service()
    
    for family_name, template in email_service.family_templates.items():
        print(f"\n📋 {family_name.upper()} Family:")
        print(f"  - Display: {template['family_display']}")
        print(f"  - Subject: {template['subject_prefix']}")
        print(f"  - Description: {template['description']}")

def test_environment():
    """Test environment variable loading"""
    print("\n🔧 Testing Environment Variables")
    print("="*50)
    
    required_vars = [
        'AWS_ACCESS_KEY_ID',
        'AWS_SECRET_ACCESS_KEY', 
        'SES_REGION',
        'SES_FROM_EMAIL',
        'GOOGLE_CLIENT_ID',
        'GOOGLE_CLIENT_SECRET',
        'JWT_SECRET'
    ]
    
    missing_vars = []
    
    for var in required_vars:
        value = os.getenv(var)
        if value:
            # Show partial value for security
            if 'SECRET' in var or 'KEY' in var:
                display_value = value[:8] + "..." if len(value) > 8 else "***"
            else:
                display_value = value
            print(f"✓ {var}: {display_value}")
        else:
            print(f"❌ {var}: NOT SET")
            missing_vars.append(var)
    
    if missing_vars:
        print(f"\n⚠️ Missing environment variables: {', '.join(missing_vars)}")
        return False
    
    print(f"\n✅ All required environment variables are set!")
    return True

if __name__ == "__main__":
    print("🚀 Family Genealogy Platform - Email Service Test")
    print("="*60)
    
    # Test environment variables
    env_ok = test_environment()
    
    if not env_ok:
        print("\n❌ Environment variables not properly configured.")
        print("Please check your .env file and try again.")
        sys.exit(1)
    
    # Test family templates
    test_family_templates()
    
    # Test email sending
    email_ok = test_email_service()
    
    if email_ok:
        print("\n🎉 All tests completed successfully!")
        print("🔗 Next steps:")
        print("   1. Check bcherrman@gmail.com for the test email")
        print("   2. Verify the email formatting and content")
        print("   3. Test the verification link (it will fail since this is just a test)")
        print("   4. Ready to deploy the FastAPI backend!")
    else:
        print("\n❌ Email test failed!")
        print("🔍 Check your SES configuration and AWS credentials.")
        sys.exit(1)