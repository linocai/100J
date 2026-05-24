"""Email sender for one-time login codes.

Behaviour (v1.2.4 #21):

- Production + ``EMAIL_OTP_ENABLED=true`` + no ``SMTP_HOST`` → raise so the
  request fails loudly instead of printing the code to stdout.
- Production + ``SMTP_HOST`` configured → real SMTP over SSL.
- Development → print to stdout with a clear ``[DEV ONLY]`` prefix.
"""

from __future__ import annotations

import smtplib
from email.message import EmailMessage
from typing import Callable

from app.core.config import get_settings


EmailSender = Callable[[str, str], None]


def _print_sender(prefix: str = "[DEV ONLY]") -> EmailSender:
    def send(email: str, code: str) -> None:
        print(f"{prefix} [OTP] {email} -> {code}")

    return send


def _smtp_sender() -> EmailSender:
    settings = get_settings()

    def send(email: str, code: str) -> None:
        message = EmailMessage()
        message["Subject"] = "100J 一次性登录验证码"
        message["From"] = settings.smtp_from or settings.smtp_user
        message["To"] = email
        message.set_content(
            f"您的 100J 登录验证码是：{code}\n\n"
            "该验证码 10 分钟内有效，仅供本次登录使用。如果不是您本人操作，请忽略本邮件。"
        )
        with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port) as smtp:
            if settings.smtp_user:
                smtp.login(settings.smtp_user, settings.smtp_password)
            smtp.send_message(message)

    return send


def _raise_unconfigured_sender() -> EmailSender:
    def send(email: str, code: str) -> None:
        raise NotImplementedError(
            "SMTP not configured; refusing to print OTP to logs."
        )

    return send


def get_email_sender() -> EmailSender:
    settings = get_settings()
    if settings.app_env == "production":
        if settings.email_otp_enabled and not settings.smtp_host:
            return _raise_unconfigured_sender()
        if settings.smtp_host:
            return _smtp_sender()
        # Production but OTP disabled — return a noisy no-op that still refuses.
        return _raise_unconfigured_sender()
    # Development / staging — keep the legacy stdout sender, but flag it.
    return _print_sender()
