#!/usr/bin/env python3
"""
Simple SES email test - sends to bcherrman@gmail.com
This assumes you have AWS credentials configured in your .env file
"""

import os
import sys
from pathlib import Path
import boto3
from dotenv import load_dotenv

# Load environment variables using dotenv
def load_env_files():
    """Load .env file using dotenv from project root"""
    try:
        # Change to project root directory for dotenv
        project_root = Path(__file__).parent.parent
        original_cwd = os.getcwd()
        
        try:
            os.chdir(project_root)
            # Load .env from project root
            result = load_dotenv(override=True)
            print(f"✓ Called load_dotenv() from project root: {project_root}")
            return result
        finally:
            os.chdir(original_cwd)
            
    except Exception as e:
        print(f"⚠️ Error with dotenv: {e}")
        return False

def test_ses_direct():
    """Test SES directly with boto3"""
    print("\n🧪 Testing Direct SES Email Send")
    print("="*50)
    
    # Check required environment variables
    aws_access_key = os.getenv("AWS_ACCESS_KEY_ID")
    aws_secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
    ses_region = os.getenv("SES_REGION", "us-east-1")
    from_email = os.getenv("SES_FROM_EMAIL", "family@futurelink.zip")
    
    if not aws_access_key or not aws_secret_key:
        print("❌ AWS credentials not found in environment variables")
        print("   Need: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY")
        return False
    
    print(f"✓ AWS Access Key: {aws_access_key[:8]}...")
    print(f"✓ AWS Secret Key: {aws_secret_key[:8]}...")
    print(f"✓ SES Region: {ses_region}")
    print(f"✓ From Email: {from_email}")
    
    try:
        # Create SES client
        ses_client = boto3.client(
            'ses',
            aws_access_key_id=aws_access_key,
            aws_secret_access_key=aws_secret_key,
            region_name=ses_region
        )
        
        # Test email details
        to_email = "bcherrman@gmail.com"
        subject = "[Family Archives Test] Email Service Verification"
        
        html_body = f"""
        <html>
        <body>
            <h2>🎉 SES Email Service Test Successful!</h2>
            <p>Hello!</p>
            <p>This is a test email from the <strong>Family Genealogy Platform</strong> backend service.</p>
            <ul>
                <li><strong>Service:</strong> Amazon SES</li>
                <li><strong>Region:</strong> {ses_region}</li>
                <li><strong>From:</strong> {from_email}</li>
                <li><strong>Family Platform:</strong> family.futurelink.zip</li>
            </ul>
            <p>If you received this email, the SES configuration is working correctly!</p>
            <hr>
            <small>Family Genealogy Platform - Multi-family authentication system</small>
        </body>
        </html>
        """
        
        text_body = f"""
Family Archives Test - Email Service Verification

Hello!

This is a test email from the Family Genealogy Platform backend service.

- Service: Amazon SES  
- Region: {ses_region}
- From: {from_email}
- Family Platform: family.futurelink.zip

If you received this email, the SES configuration is working correctly!

---
Family Genealogy Platform - Multi-family authentication system
        """
        
        print(f"\n📧 Sending test email to: {to_email}")
        
        # Send the email
        response = ses_client.send_email(
            Source=from_email,
            Destination={'ToAddresses': [to_email]},
            Message={
                'Subject': {'Data': subject, 'Charset': 'UTF-8'},
                'Body': {
                    'Html': {'Data': html_body, 'Charset': 'UTF-8'},
                    'Text': {'Data': text_body, 'Charset': 'UTF-8'}
                }
            }
        )
        
        print(f"✅ EMAIL SENT SUCCESSFULLY!")
        print(f"   Message ID: {response['MessageId']}")
        print(f"   Check {to_email} for the test email")
        return True
        
    except Exception as e:
        print(f"❌ EMAIL SEND FAILED!")
        print(f"   Error: {str(e)}")
        
        # Check if it's an authentication issue
        if "InvalidUserPoolConfigurationException" in str(e) or "UnauthorizedOperation" in str(e):
            print("   💡 This looks like an AWS credentials issue")
        elif "MessageRejected" in str(e):
            print("   💡 This might be a domain verification issue")
        elif "SendingQuotaExceededException" in str(e):
            print("   💡 SES sending quota exceeded")
        
        return False

if __name__ == "__main__":
    print("🚀 Simple SES Email Test")
    print("="*40)
    
    # Load environment
    load_env_files()
    
    # Test SES
    success = test_ses_direct()
    
    if success:
        print("\n🎉 SES test completed successfully!")
        print("   Ready to proceed with the full authentication backend!")
    else:
        print("\n❌ SES test failed!")
        print("   Please check your AWS credentials and SES configuration.")
    
    print("\n🔗 Next steps:")
    print("   1. If email sent successfully, check bcherrman@gmail.com")
    print("   2. Verify the email looks good and is properly formatted")
    print("   3. Test the FastAPI backend with: python main.py")