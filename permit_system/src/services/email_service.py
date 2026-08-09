import os
import smtplib
from email.message import EmailMessage

from src.infra.database.models import SecretariaModel


DEFAULT_CITY_HEADER = "Prefeitura Municipal de Valença - Central de Eventos"


def send_email(destinatario: str, assunto: str, texto: str, html: str | None = None) -> str:
    host = os.getenv("SMTP_HOST")
    if not host:
        return "SMTP não configurado; notificação registrada no processo."

    port = int(os.getenv("SMTP_PORT", "587"))
    smtp_from = os.getenv("SMTP_FROM") or os.getenv("SMTP_USER") or "no-reply@valenca.ba.gov.br"
    msg = EmailMessage()
    msg["From"] = smtp_from
    msg["To"] = destinatario
    msg["Subject"] = assunto
    msg.set_content(texto)
    if html:
        msg.add_alternative(html, subtype="html")

    try:
        with smtplib.SMTP(host, port, timeout=10) as smtp:
            if os.getenv("SMTP_USE_TLS", "true").lower() in {"1", "true", "yes"}:
                smtp.starttls()
            user = os.getenv("SMTP_USER")
            password = os.getenv("SMTP_PASSWORD")
            if user and password:
                smtp.login(user, password)
            smtp.send_message(msg)
        return "E-mail enviado via SMTP."
    except Exception as exc:  # pragma: no cover - depende do provedor SMTP externo.
        return f"Falha no SMTP; notificação registrada no processo. Erro: {exc}"


def build_mfa_email_html(code: str, secretaria: SecretariaModel | None = None) -> str:
    header = secretaria.email_header_text if secretaria and secretaria.email_header_text else DEFAULT_CITY_HEADER
    logo_url = secretaria.logo_url if secretaria and secretaria.logo_url else os.getenv("PREFEITURA_LOGO_URL", "")
    secretaria_name = secretaria.nome if secretaria else "Prefeitura Municipal de Valença"
    logo = f'<img src="{logo_url}" alt="{secretaria_name}" style="max-height:72px;margin-bottom:16px;">' if logo_url else ""
    return f"""
    <div style="font-family:Arial,sans-serif;max-width:640px;margin:0 auto;color:#1f2937;">
      <div style="border-bottom:4px solid #0f7b3f;padding:20px 0;text-align:center;">
        {logo}
        <h1 style="font-size:20px;margin:0;">{header}</h1>
      </div>
      <div style="padding:24px 0;">
        <p>Use o código abaixo para concluir seu acesso ao sistema municipal:</p>
        <p style="font-size:32px;font-weight:700;letter-spacing:6px;margin:24px 0;color:#0f7b3f;">{code}</p>
        <p>O código expira em 5 minutos. Se você não solicitou este acesso, ignore esta mensagem.</p>
      </div>
      <div style="border-top:1px solid #e5e7eb;padding-top:16px;font-size:12px;color:#6b7280;">
        {secretaria_name}
      </div>
    </div>
    """
