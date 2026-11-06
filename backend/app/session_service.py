"""Token issuance and revocation helpers."""

from sqlalchemy import update
from sqlalchemy.orm import Session

from .config import settings
from .models import RefreshToken, User
from .schemas import TokenResponse
from .security import create_access_token, create_refresh_token


def issue_tokens(db: Session, user: User) -> TokenResponse:
    """Create an access/refresh token pair and persist the refresh token."""
    access_token = create_access_token(user)
    refresh_token, jti, expires_at = create_refresh_token(user)

    db.add(
        RefreshToken(user_id=user.id, jti=jti, expires_at=expires_at)
    )
    db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_expire_minutes * 60,
    )


def revoke_all_refresh_tokens(
    db: Session, user_id: int, *, commit: bool = True
) -> None:
    """Revoke every active refresh token for a user."""
    db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.revoked.is_(False),
        )
        .values(revoked=True)
    )
    if commit:
        db.commit()
