import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import aiosmtplib

from app.config import settings

logger = logging.getLogger(__name__)


async def send_password_reset_email(to_email: str, reset_link: str) -> None:
    if not settings.smtp_host:
        logger.warning("SMTP not configured — password reset link for %s: %s", to_email, reset_link)
        return

    message = MIMEMultipart("alternative")
    message["Subject"] = "Reset your Gratitude password"
    message["From"] = settings.smtp_from
    message["To"] = to_email

    plain = (
        f"Hi,\n\n"
        f"Click the link below to reset your Gratitude password.\n"
        f"This link expires in 1 hour.\n\n"
        f"{reset_link}\n\n"
        f"If you didn't request this, you can ignore this email."
    )
    html = f"""
    <p>Hi,</p>
    <p>Click the button below to reset your <strong>Gratitude</strong> password.
    This link expires in <strong>1 hour</strong>.</p>
    <p style="margin:24px 0">
      <a href="{reset_link}"
         style="background:#6750a4;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:bold">
        Reset my password
      </a>
    </p>
    <p>If you didn't request this, you can safely ignore this email.</p>
    """

    message.attach(MIMEText(plain, "plain"))
    message.attach(MIMEText(html, "html"))

    await aiosmtplib.send(
        message,
        hostname=settings.smtp_host,
        port=settings.smtp_port,
        username=settings.smtp_username or None,
        password=settings.smtp_password or None,
        start_tls=settings.smtp_tls,
    )
