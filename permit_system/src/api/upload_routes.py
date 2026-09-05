import os
import re
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, Form, Header, HTTPException, UploadFile, status

from src.core.security import decode_token

router = APIRouter(prefix="/uploads", tags=["uploads"])

UPLOAD_ROOT = Path(os.getenv("UPLOAD_ROOT", "/app/uploads"))
MAX_UPLOAD_BYTES = int(os.getenv("MAX_UPLOAD_BYTES", str(10 * 1024 * 1024)))
ALLOWED_EXTENSIONS = {".pdf", ".jpg", ".jpeg", ".png"}
PUBLIC_UPLOAD_KINDS = {"usuarios/fotos", "usuarios/comprovantes"}


@router.post("")
def upload_file(
    kind: str = Form("geral"),
    file: UploadFile = File(...),
    authorization: str | None = Header(default=None),
):
    if kind not in PUBLIC_UPLOAD_KINDS:
        _validate_bearer_token(authorization)
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Formato de arquivo não permitido.",
        )

    safe_kind = re.sub(r"[^a-zA-Z0-9_-]", "_", kind or "geral")[:40]
    target_dir = UPLOAD_ROOT / safe_kind
    target_dir.mkdir(parents=True, exist_ok=True)

    safe_name = re.sub(r"[^a-zA-Z0-9_.-]", "_", file.filename or f"arquivo{suffix}")
    final_name = f"{uuid4().hex}_{safe_name}"
    target_path = target_dir / final_name

    size = 0
    with target_path.open("wb") as output:
        while chunk := file.file.read(1024 * 1024):
            size += len(chunk)
            if size > MAX_UPLOAD_BYTES:
                output.close()
                target_path.unlink(missing_ok=True)
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail="Arquivo maior que o limite permitido.",
                )
            output.write(chunk)

    return {
        "file_name": file.filename,
        "file_url": f"/uploads/{safe_kind}/{final_name}",
        "mime_type": file.content_type,
        "size_bytes": size,
    }


def _validate_bearer_token(authorization: str | None) -> None:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sessão necessária para anexar arquivos.",
        )
    try:
        decode_token(authorization.split(" ", 1)[1])
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sessão inválida para anexar arquivos.",
        ) from exc
