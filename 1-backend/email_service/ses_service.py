"""
SES Email Service for Family Genealogy Platform
Based on existing ses_config.py pattern with family-aware templates
"""

import os
import json
import time
import random
import string
from typing import Dict, Optional, Union, Literal
from dataclasses import dataclass
from enum import Enum
import logging
import boto3
from botocore.exceptions import ClientError
from datetime import datetime, timezone

# Configure logging
logger = logging.getLogger(__name__)

class SesMode(Enum):
    """SES transport modes"""
    SMTP = "smtp"
    SDK = "sdk"  # Using boto3 SES client directly


@dataclass
class SesConfig:
    """SES configuration data structure"""
    smtp_user: str = ""
    smtp_pass: str = ""
    access_key_id: str = ""
    secret_access_key: str = ""
    region: str = "us-east-1"
    from_email: str = "family@futurelink.zip"
    mode: SesMode = SesMode.SDK


class FamilyEmailService:
    """
    Family-specific email service using Amazon SES
    Follows the same approach as existing SES configuration service
    """
    
    _instance: Optional['FamilyEmailService'] = None
    CACHE_TTL = 3600  # 1 hour cache TTL
    
    def __init__(self):
        self._cached_config: Optional[SesConfig] = None
        self._cache_expiry: float = 0
        self._ses_client = None
        self._is_cloud_environment = self._detect_cloud_environment()
        
        # Family-specific email templates
        self.family_templates = {
            "bull": {
                "subject_prefix": "[Bull Family Archives]",
                "family_display": "Bull Family",
                "description": "Gladys Klingenberg's life story and Bull family history"
            },
            "north": {
                "subject_prefix": "[North Family Archives]", 
                "family_display": "North Family",
                "description": "North family genealogy and historical records"
            },
            "klingenberg": {
                "subject_prefix": "[Klingenberg Family Archives]",
                "family_display": "Klingenberg Family", 
                "description": "Klingenberg family heritage and genealogy"
            },
            "herrman": {
                "subject_prefix": "[Herrman Family Archives]",
                "family_display": "Herrman Family",
                "description": "Herrman family history and genealogical records"
            }
        }
    
    @classmethod
    def get_instance(cls) -> 'FamilyEmailService':
        """Singleton instance"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    def _detect_cloud_environment(self) -> bool:
        """Detect if running in a cloud environment"""
        cloud_indicators = [
            'GOOGLE_CLOUD_PROJECT',
            'GCLOUD_PROJECT', 
            'GCP_PROJECT',
            'K_SERVICE',  # Cloud Run
            'GAE_APPLICATION',  # App Engine
            'AWS_LAMBDA_FUNCTION_NAME',  # AWS Lambda
            'AWS_EXECUTION_ENV',  # AWS environments
        ]
        
        return any(os.getenv(indicator) for indicator in cloud_indicators)
    
    def get_ses_config(self) -> SesConfig:
        """
        Get SES configuration with caching
        
        Returns:
            SesConfig: The SES configuration
        """
        # Return cached config if still valid
        if self._cached_config and time.time() < self._cache_expiry:
            return self._cached_config
        
        # Load fresh config
        if self._is_cloud_environment:
            logger.info("Loading SES configuration for cloud environment")
            config = self._get_config_from_environment()
        else:
            logger.info("Loading SES configuration from local environment")
            config = self._get_config_from_environment()
        
        # Cache the configuration
        self._cached_config = config
        self._cache_expiry = time.time() + self.CACHE_TTL
        
        logger.info("SES configuration loaded successfully", extra={
            'region': config.region,
            'mode': config.mode.value,
            'from_email': config.from_email,
            'source': 'cloud' if self._is_cloud_environment else 'local'
        })
        
        return config
    
    def _get_config_from_environment(self) -> SesConfig:
        """
        Get SES configuration from environment variables
        
        Returns:
            SesConfig: Configuration loaded from environment
            
        Raises:
            ValueError: If required configuration is missing
        """
        # Determine mode from environment
        mode_str = os.getenv('EMAIL_PROVIDER_MODE', 'sdk').lower()
        mode = SesMode.SMTP if mode_str == 'smtp' else SesMode.SDK
        
        config = SesConfig(
            smtp_user=os.getenv('SES_SMTP_USER', ''),
            smtp_pass=os.getenv('SES_SMTP_PASS', ''),
            access_key_id=os.getenv('AWS_ACCESS_KEY_ID', ''),
            secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY', ''),
            region=os.getenv('SES_REGION', os.getenv('AWS_REGION', 'us-east-1')),
            from_email=os.getenv('SES_FROM_EMAIL', 'family@futurelink.zip'),
            mode=mode
        )
        
        # Validate configuration
        self._validate_ses_config(config)
        
        return config
    
    def _validate_ses_config(self, config: SesConfig) -> None:
        """
        Validate SES configuration
        
        Args:
            config: Configuration to validate
            
        Raises:
            ValueError: If configuration is invalid
        """
        if config.mode == SesMode.SDK:
            required_fields = ['access_key_id', 'secret_access_key', 'region', 'from_email']
            missing_fields = [field for field in required_fields if not getattr(config, field)]
        else:  # SMTP mode
            required_fields = ['smtp_user', 'smtp_pass', 'region', 'from_email']
            missing_fields = [field for field in required_fields if not getattr(config, field)]
        
        if missing_fields:
            raise ValueError(f"Missing required SES configuration fields: {', '.join(missing_fields)}")
        
        # Validate region format
        if not config.region or not config.region.replace('-', '').replace('_', '').isalnum():
            raise ValueError(f"Invalid AWS region format: {config.region}")
        
        # Validate email format
        if not self._is_valid_email(config.from_email):
            raise ValueError(f"Invalid from email format: {config.from_email}")
    
    def _is_valid_email(self, email: str) -> bool:
        """Simple email validation"""
        return '@' in email and '.' in email.split('@')[1] and len(email.split('@')) == 2
    
    def _get_ses_client(self):
        """Get or create SES client"""
        if self._ses_client is None:
            config = self.get_ses_config()
            self._ses_client = boto3.client(
                'ses',
                aws_access_key_id=config.access_key_id,
                aws_secret_access_key=config.secret_access_key,
                region_name=config.region
            )
        return self._ses_client
    
    def generate_verification_code(self) -> str:
        """Generate 6-digit verification code"""
        return ''.join(random.choices(string.digits, k=6))
    
    def send_family_verification_email(self, email: str, family_name: str, verification_code: str, 
                                     verification_link: str) -> Dict[str, any]:
        """
        Send family-specific verification email
        
        Args:
            email: Recipient email address
            family_name: Family name (bull, north, etc.)
            verification_code: 6-digit verification code
            verification_link: Full verification URL
            
        Returns:
            Dict with success status and message ID or error
        """
        try:
            family_info = self.family_templates.get(family_name, {
                "subject_prefix": "[Family Archives]",
                "family_display": family_name.title() + " Family",
                "description": f"{family_name.title()} family genealogy and records"
            })
            
            subject = f"{family_info['subject_prefix']} Verify Your Access - Code: {verification_code}"
            
            html_body = self._create_verification_email_html(
                email, family_name, family_info, verification_code, verification_link
            )
            
            text_body = self._create_verification_email_text(
                email, family_name, family_info, verification_code, verification_link
            )
            
            config = self.get_ses_config()
            ses_client = self._get_ses_client()
            
            response = ses_client.send_email(
                Source=config.from_email,
                Destination={'ToAddresses': [email]},
                Message={
                    'Subject': {'Data': subject, 'Charset': 'UTF-8'},
                    'Body': {
                        'Html': {'Data': html_body, 'Charset': 'UTF-8'},
                        'Text': {'Data': text_body, 'Charset': 'UTF-8'}
                    }
                }
            )
            
            logger.info(f"Verification email sent successfully", extra={
                'email': email,
                'family': family_name,
                'message_id': response['MessageId']
            })
            
            return {
                'success': True,
                'message_id': response['MessageId'],
                'family': family_name
            }
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            
            logger.error(f"SES error sending verification email", extra={
                'email': email,
                'family': family_name,
                'error_code': error_code,
                'error_message': error_message
            })
            
            return {
                'success': False,
                'error': f"Email service error: {error_code}",
                'message': error_message
            }
            
        except Exception as e:
            logger.error(f"Unexpected error sending verification email", extra={
                'email': email,
                'family': family_name,
                'error': str(e)
            })
            
            return {
                'success': False,
                'error': "Unexpected error sending email",
                'message': str(e)
            }
    
    def _create_verification_email_html(self, email: str, family_name: str, family_info: Dict, 
                                      verification_code: str, verification_link: str) -> str:
        """Create HTML email body for verification"""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Verify Your Access - {family_info['family_display']}</title>
        </head>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px;">
                    {family_info['family_display']} Archives
                </h1>
                <p style="color: #7f8c8d; font-size: 14px;">family.futurelink.zip/{family_name}</p>
            </div>
            
            <div style="background: #f8f9fa; padding: 25px; border-radius: 8px; border-left: 4px solid #3498db; margin-bottom: 25px;">
                <h2 style="color: #2c3e50; margin-top: 0;">Verify Your Email Address</h2>
                <p>Hi there!</p>
                <p>You've requested access to the <strong>{family_info['family_display']}</strong> genealogy archives. {family_info['description']}.</p>
                
                <div style="text-align: center; margin: 25px 0;">
                    <div style="background: #3498db; color: white; font-size: 24px; font-weight: bold; padding: 15px; border-radius: 8px; letter-spacing: 3px; display: inline-block;">
                        {verification_code}
                    </div>
                </div>
                
                <p>Or click the link below to verify your access:</p>
                <div style="text-align: center; margin: 20px 0;">
                    <a href="{verification_link}" 
                       style="background: #27ae60; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block;">
                        Verify Email & Access Archives
                    </a>
                </div>
                
                <p style="font-size: 14px; color: #7f8c8d;">
                    <strong>Note:</strong> This verification link will expire in 30 minutes for security purposes.
                </p>
            </div>
            
            <div style="background: #ecf0f1; padding: 20px; border-radius: 8px; font-size: 14px;">
                <h3 style="color: #2c3e50; margin-top: 0;">What's Next?</h3>
                <ul style="color: #5d6d7e;">
                    <li>Click the verification link or enter the code above</li>
                    <li>Review and accept our terms and privacy policy</li>
                    <li>Choose your marketing preferences</li>
                    <li>Start exploring the {family_info['family_display']} archives!</li>
                </ul>
            </div>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ecf0f1; color: #7f8c8d; font-size: 12px;">
                <p>Family Genealogy Platform | family.futurelink.zip</p>
                <p>Preserving family histories with modern technology</p>
                <p>If you didn't request this, you can safely ignore this email.</p>
            </div>
        </body>
        </html>
        """
    
    def _create_verification_email_text(self, email: str, family_name: str, family_info: Dict, 
                                      verification_code: str, verification_link: str) -> str:
        """Create text email body for verification"""
        return f"""
{family_info['family_display']} Archives - Email Verification

Hi there!

You've requested access to the {family_info['family_display']} genealogy archives.
{family_info['description']}.

Your verification code is: {verification_code}

Or verify your email by visiting this link:
{verification_link}

What's next?
1. Click the verification link or enter the code above
2. Review and accept our terms and privacy policy  
3. Choose your marketing preferences
4. Start exploring the {family_info['family_display']} archives!

Note: This verification link will expire in 30 minutes for security purposes.

---
Family Genealogy Platform
family.futurelink.zip
Preserving family histories with modern technology

If you didn't request this, you can safely ignore this email.
        """
    
    def send_family_magic_link(self, email: str, family_name: str, invitation_code: str, 
                             magic_link: str, description: str = None) -> Dict[str, any]:
        """
        Send family magic login link email
        """
        try:
            family_info = self.family_templates.get(family_name, {
                "subject_prefix": "[Family Archives]",
                "family_display": family_name.title() + " Family",
                "description": f"{family_name.title()} family genealogy and records"
            })
            
            subject = f"{family_info['subject_prefix']} Welcome to {family_info['family_display']}!"
            
            html_body = f"""
            <html><body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px;">
                    🏛️ {family_info['family_display']} Archives
                </h1>
                <p style="color: #7f8c8d; font-size: 14px;">family.futurelink.zip/families/{family_name}</p>
            </div>
            
            <div style="background: #f8f9fa; padding: 25px; border-radius: 8px; border-left: 4px solid #27ae60; margin-bottom: 25px;">
                <h2 style="color: #2c3e50; margin-top: 0;">🎉 Welcome to {family_info['family_display']}!</h2>
                <p>You've been invited to access your family archives. Click the button below to get started:</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{magic_link}" 
                       style="background: #27ae60; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; display: inline-block;">
                        🚀 Access {family_info['family_display']} Archives
                    </a>
                </div>
                
                <p><strong>What you'll find inside:</strong></p>
                <ul style="color: #2c3e50;">
                    <li>✅ Family history and genealogy</li>
                    <li>✅ Photos and memories</li>
                    <li>✅ Stories and documents</li>
                    <li>✅ Connect with family members</li>
                </ul>
                
                {f'<p><strong>About this family:</strong> {description}</p>' if description else ''}
            </div>
            
            <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                <h3 style="color: #1976d2; margin-top: 0;">📧 Share with Family</h3>
                <p>Your family invitation code: <strong style="font-family: monospace; background: #fff; padding: 2px 6px; border-radius: 3px;">{invitation_code}</strong></p>
                <p>Share this code with other family members so they can join too!</p>
            </div>
            
            <div style="background: #fff3cd; padding: 15px; border-radius: 8px; border-left: 4px solid #ffc107; margin: 20px 0;">
                <p style="margin: 0; color: #856404; font-size: 14px;">
                    <strong>💡 One-Click Access:</strong> This link will automatically log you in. No passwords needed!
                </p>
            </div>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ecf0f1; color: #7f8c8d; font-size: 12px;">
                <p>Family Genealogy Platform | family.futurelink.zip</p>
                <p>Preserving family histories with modern technology</p>
            </div>
            </body></html>
            """
            
            text_body = f"""
            🏛️ {family_info['family_display']} Archives - Welcome!
            
            Welcome to {family_info['family_display']}!
            
            You've been invited to access your family archives.
            
            Click here to get started: {magic_link}
            
            What you'll find:
            ✅ Family history and genealogy
            ✅ Photos and memories  
            ✅ Stories and documents
            ✅ Connect with family members
            
            {f'About this family: {description}' if description else ''}
            
            Share with Family:
            Your invitation code: {invitation_code}
            
            💡 This link will automatically log you in. No passwords needed!
            
            ---
            Family Genealogy Platform | family.futurelink.zip
            Preserving family histories with modern technology
            """
            
            config = self.get_ses_config()
            ses_client = self._get_ses_client()
            
            response = ses_client.send_email(
                Source=config.from_email,
                Destination={'ToAddresses': [email]},
                Message={
                    'Subject': {'Data': subject, 'Charset': 'UTF-8'},
                    'Body': {
                        'Html': {'Data': html_body, 'Charset': 'UTF-8'},
                        'Text': {'Data': text_body, 'Charset': 'UTF-8'}
                    }
                }
            )
            
            logger.info(f"Magic link email sent successfully", extra={
                'email': email,
                'family': family_name,
                'invitation_code': invitation_code,
                'message_id': response['MessageId']
            })
            
            return {
                'success': True,
                'message_id': response['MessageId'],
                'family': family_name,
                'invitation_code': invitation_code
            }
            
        except Exception as e:
            logger.error(f"Error sending magic link email: {e}")
            return {
                'success': False,
                'error': "Failed to send magic link email",
                'message': str(e)
            }
    
    def clear_cache(self) -> None:
        """Clear cached configuration (force reload on next request)"""
        self._cached_config = None
        self._cache_expiry = 0
        self._ses_client = None
        logger.info("SES configuration cache cleared")


# Convenience functions
def get_family_email_service() -> FamilyEmailService:
    """
    Convenience function to get family email service
    
    Returns:
        FamilyEmailService: Current email service instance
    """
    return FamilyEmailService.get_instance()


def send_verification_email(email: str, family_name: str, verification_code: str, 
                          verification_link: str) -> Dict[str, any]:
    """
    Convenience function to send verification email
    
    Args:
        email: Recipient email address
        family_name: Family name (bull, north, etc.)
        verification_code: 6-digit verification code
        verification_link: Full verification URL
        
    Returns:
        Dict with success status and message ID or error
    """
    service = get_family_email_service()
    return service.send_family_verification_email(email, family_name, verification_code, verification_link)
    def send_family_invitation_code(self, email: str, family_name: str, invitation_code: str, 
                                  description: str = None) -> Dict[str, any]:
        """
        Send family invitation code email
        
        Args:
            email: Recipient email address
            family_name: Family name (bull, north, etc.)
            invitation_code: 8-character invitation code
            description: Optional family description
            
        Returns:
            Dict with success status and message ID or error
        """
        try:
            family_info = self.family_templates.get(family_name, {
                "subject_prefix": "[Family Archives]",
                "family_display": family_name.title() + " Family",
                "description": f"{family_name.title()} family genealogy and records"
            })
            
            subject = f"{family_info['subject_prefix']} Your Family Invitation Code: {invitation_code}"
            
            html_body = self._create_invitation_email_html(
                email, family_name, family_info, invitation_code, description
            )
            
            text_body = self._create_invitation_email_text(
                email, family_name, family_info, invitation_code, description
            )
            
            config = self.get_ses_config()
            ses_client = self._get_ses_client()
            
            response = ses_client.send_email(
                Source=config.from_email,
                Destination={'ToAddresses': [email]},
                Message={
                    'Subject': {'Data': subject, 'Charset': 'UTF-8'},
                    'Body': {
                        'Html': {'Data': html_body, 'Charset': 'UTF-8'},
                        'Text': {'Data': text_body, 'Charset': 'UTF-8'}
                    }
                }
            )
            
            logger.info(f"Invitation code email sent successfully", extra={
                'email': email,
                'family': family_name,
                'invitation_code': invitation_code,
                'message_id': response['MessageId']
            })
            
            return {
                'success': True,
                'message_id': response['MessageId'],
                'family': family_name,
                'invitation_code': invitation_code
            }
            
        except Exception as e:
            logger.error(f"Error sending invitation email", extra={
                'email': email,
                'family': family_name,
                'invitation_code': invitation_code,
                'error': str(e)
            })
            
            return {
                'success': False,
                'error': "Failed to send invitation email",
                'message': str(e)
            }
    
    def _create_invitation_email_html(self, email: str, family_name: str, family_info: Dict,
                                    invitation_code: str, description: str = None) -> str:
        """Create HTML email body for invitation code"""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Your {family_info['family_display']} Invitation Code</title>
        </head>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px;">
                    🏛️ {family_info['family_display']} Archives
                </h1>
                <p style="color: #7f8c8d; font-size: 14px;">family.futurelink.zip/families/{family_name}</p>
            </div>
            
            <div style="background: #f8f9fa; padding: 25px; border-radius: 8px; border-left: 4px solid #27ae60; margin-bottom: 25px;">
                <h2 style="color: #2c3e50; margin-top: 0;">🎉 Welcome to {family_info['family_display']}!</h2>
                <p>Congratulations! You've created your family archives. Here's your invitation code to share with family members:</p>
                
                <div style="text-align: center; margin: 25px 0;">
                    <div style="background: #27ae60; color: white; font-size: 32px; font-weight: bold; padding: 20px; border-radius: 8px; letter-spacing: 4px; display: inline-block; font-family: monospace;">
                        {invitation_code}
                    </div>
                </div>
                
                <p><strong>Share this code with your family members so they can:</strong></p>
                <ul>
                    <li>✅ Access the {family_info['family_display']} archives</li>
                    <li>✅ View and contribute to family history</li>
                    <li>✅ Connect with other family members</li>
                    <li>✅ Preserve memories for future generations</li>
                </ul>
                
                {f'<p><strong>Family Description:</strong> {description}</p>' if description else ''}
            </div>
            
            <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                <h3 style="color: #1976d2; margin-top: 0;">📧 How to Share</h3>
                <p style="margin: 10px 0;"><strong>Simply tell your family:</strong></p>
                <p style="background: white; padding: 15px; border-radius: 5px; margin: 10px 0; font-style: italic;">
                    "Visit <strong>family.futurelink.zip</strong> and use invitation code <strong>{invitation_code}</strong> to join our {family_info['family_display']} archives!"
                </p>
            </div>
            
            <div style="background: #fff3cd; padding: 15px; border-radius: 8px; border-left: 4px solid #ffc107; margin: 20px 0;">
                <p style="margin: 0; color: #856404;"><strong>💡 Pro Tip:</strong> Save this email! You can always reference this invitation code to invite more family members later.</p>
            </div>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ecf0f1; color: #7f8c8d; font-size: 12px;">
                <p>Family Genealogy Platform | family.futurelink.zip</p>
                <p>Preserving family histories with modern technology</p>
            </div>
        </body>
        </html>
        """
    
    def _create_invitation_email_text(self, email: str, family_name: str, family_info: Dict,
                                    invitation_code: str, description: str = None) -> str:
        """Create text email body for invitation code"""
        return f"""
🏛️ {family_info['family_display']} Archives - Invitation Code

Congratulations! You've created your family archives.

Your invitation code: {invitation_code}

Share this code with your family members so they can:
✅ Access the {family_info['family_display']} archives  
✅ View and contribute to family history
✅ Connect with other family members
✅ Preserve memories for future generations

{f'Family Description: {description}' if description else ''}

How to Share:

Simply tell your family:
"Visit family.futurelink.zip and use invitation code {invitation_code} to join our {family_info['family_display']} archives!"

💡 Pro Tip: Save this email! You can always reference this invitation code to invite more family members later.

---
Family Genealogy Platform
family.futurelink.zip
Preserving family histories with modern technology
        """
