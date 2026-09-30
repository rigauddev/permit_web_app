import os
import smtplib
import html
import json
from email.message import EmailMessage

from sqlalchemy.orm import Session

from src.infra.database.models import ContentSettingModel, SecretariaModel


DEFAULT_CITY_HEADER = "Prefeitura Municipal de Valença - Central de Eventos"

DEFAULT_EMAIL_TEMPLATES = {
    'welcome': {
        'subject': 'Boas-vindas ao Sistema de Serviços de Valença',
        'header_text': 'Seja bem-vindo(a)!',
        'body_text': 'Olá, {{nome}}. Sua conta foi criada com sucesso. Acesse o sistema para acompanhar seus serviços municipais.',
        'footer_text': 'Prefeitura Municipal de Valença • Secretaria de Mobilidade Pública - SEMOP',
        'logo_mode': 'system', 'logo_url': None,
    },
    'blocked': {
        'subject': 'Conta bloqueada no Sistema de Serviços de Valença',
        'header_text': 'Atualização da sua conta',
        'body_text': 'Olá, {{nome}}. Sua conta foi bloqueada. Caso precise de ajuda, entre em contato com a Prefeitura.',
        'footer_text': 'Prefeitura Municipal de Valença • Secretaria de Mobilidade Pública - SEMOP',
        'logo_mode': 'system', 'logo_url': None,
    },
    'password_recovery': {
        'subject': 'Recuperação de senha',
        'header_text': 'Recupere seu acesso',
        'body_text': 'Olá, {{nome}}. Use o código {{codigo}} para recuperar sua senha. Se você não fez esta solicitação, ignore esta mensagem.',
        'footer_text': 'Prefeitura Municipal de Valença • Secretaria de Mobilidade Pública - SEMOP',
        'logo_mode': 'system', 'logo_url': None,
    },
}


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


def render_configured_email_template(
    db: Session,
    template_key: str,
    values: dict[str, str],
) -> tuple[str, str, str]:
    """Returns subject, plain text and safe HTML from the administrator template."""
    template = DEFAULT_EMAIL_TEMPLATES[template_key].copy()
    row = db.query(ContentSettingModel).filter(ContentSettingModel.key == 'email_templates').first()
    if row:
        try:
            stored = json.loads(row.value)
            if isinstance(stored, dict) and isinstance(stored.get(template_key), dict):
                template.update(stored[template_key])
        except (TypeError, ValueError):
            pass
    def replace(value: str) -> str:
        for key, replacement in values.items():
            value = value.replace('{{' + key + '}}', replacement)
        return value
    subject = replace(str(template['subject']))
    header = replace(str(template['header_text']))
    body = replace(str(template['body_text']))
    footer = replace(str(template['footer_text']))
    logo_url = template.get('logo_url') if template.get('logo_mode') == 'custom' else os.getenv('PREFEITURA_LOGO_URL', '')
    logo = f'<img src="{html.escape(str(logo_url), quote=True)}" alt="Prefeitura de Valença" style="max-height:72px;margin-bottom:16px;">' if logo_url else ''
    html_body = f'''<div style="font-family:Arial,sans-serif;max-width:640px;margin:0 auto;color:#1f2937;">
      <div style="border-bottom:4px solid #0f7b3f;padding:20px 0;text-align:center;">{logo}<h1 style="font-size:20px;margin:0;">{html.escape(header)}</h1></div>
      <div style="padding:24px 0;white-space:pre-line;">{html.escape(body)}</div>
      <div style="border-top:1px solid #e5e7eb;padding-top:16px;font-size:12px;color:#6b7280;">{html.escape(footer)}</div>
    </div>'''
    return subject, f'{header}\n\n{body}\n\n{footer}', html_body
