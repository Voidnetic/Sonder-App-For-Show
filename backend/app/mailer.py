"""Sends emails through Resend (HTTPS) or SMTP, whichever is configured. See config.py."""

import logging
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr

import requests

from app.config import settings

log = logging.getLogger("sonder.mail")


class EmailError(Exception):
    pass


def send_email(to: str, subject: str, text: str, html: str) -> None:
    """Blocking. Raises EmailError if the email could not be handed to the provider."""
    sender = formataddr((settings.email_from_name, settings.email_from))
    if settings.resend_api_key:
        try:
            response = requests.post(
                "https://api.resend.com/emails",
                headers={"Authorization": f"Bearer {settings.resend_api_key}"},
                json={"from": sender, "to": [to], "subject": subject, "text": text, "html": html},
                timeout=15,
            )
        except requests.RequestException as exc:
            raise EmailError(f"Resend request failed: {exc}") from exc
        if response.status_code >= 300:
            raise EmailError(f"Resend rejected the email ({response.status_code}): {response.text[:300]}")
        return

    message = EmailMessage()
    message["From"], message["To"], message["Subject"] = sender, to, subject
    message.set_content(text)
    message.add_alternative(html, subtype="html")
    try:
        if settings.smtp_port == 465:
            with smtplib.SMTP_SSL(settings.smtp_host, 465, context=ssl.create_default_context(), timeout=15) as s:
                s.login(settings.smtp_username or settings.email_from, settings.smtp_password)
                s.send_message(message)
        else:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as s:
                s.starttls(context=ssl.create_default_context())
                s.login(settings.smtp_username or settings.email_from, settings.smtp_password)
                s.send_message(message)
    except (smtplib.SMTPException, OSError) as exc:
        raise EmailError(f"SMTP failed: {exc}") from exc


def code_email(code: str, purpose: str) -> tuple[str, str, str]:
    """Subject, plain text and HTML for a 6-digit code."""
    action = "verify your email" if purpose == "verify" else "reset your password"
    subject = f"{code} is your Sonder code"
    text = (
        f"Your Sonder code is {code}\n\nEnter it in the app to {action}. It expires in 15 minutes.\n\n"
        "If you didn't ask for this, you can ignore this email."
    )
    html = f"""<div style="font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#FAF9F6;padding:32px">
  <div style="max-width:440px;margin:auto;background:#fff;border:2px solid #1C1C1C;border-radius:20px;padding:28px;
              box-shadow:4px 4px 0 #1C1C1C">
    <div style="font-weight:900;letter-spacing:3px;font-size:13px">SONDER</div>
    <p style="font-size:16px;color:#1C1C1C">Enter this code in the app to {action}:</p>
    <div style="font-size:38px;font-weight:900;letter-spacing:10px;background:#FFFACD;border:2px solid #1C1C1C;
                border-radius:14px;padding:14px;text-align:center;color:#1C1C1C">{code}</div>
    <p style="font-size:13px;color:#6B6B6B">It expires in 15 minutes. If you didn't ask for this, you can ignore
       this email.</p>
  </div>
</div>"""
    return subject, text, html
