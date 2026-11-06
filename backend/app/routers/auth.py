"""Authentication endpoints: register, login, refresh, logout, passwords."""

from datetime import timedelta

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..dependencies import get_current_user
from ..models import (
    PasswordResetToken,
    ProviderProfile,
    RefreshToken,
    User,
    UserRole,
    VerificationStatus,
    utcnow,
)
from ..schemas import (
    ChangePasswordRequest,
    LoginRequest,
    PasswordResetConfirm,
    PasswordResetRequest,
    PasswordResetResponse,
    RefreshRequest,
    RegisterCustomerRequest,
    RegisterProviderRequest,
    TokenResponse,
    UserPublic,
)
from ..security import (
    create_password_reset_token,
    decode_token,
    hash_password,
    hash_reset_token,
    verify_password,
)
from ..session_service import issue_tokens, revoke_all_refresh_tokens

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/register/customer",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_customer(
    payload: RegisterCustomerRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    email = payload.email.lower()
    if db.scalar(select(User).where(User.email == email)) is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name,
        phone=payload.phone,
        role=UserRole.CUSTOMER.value,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return issue_tokens(db, user)


@router.post(
    "/register/provider",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_provider(
    payload: RegisterProviderRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    email = payload.email.lower()
    if db.scalar(select(User).where(User.email == email)) is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name,
        phone=payload.phone,
        role=UserRole.PROVIDER.value,
        is_active=True,
    )
    db.add(user)
    db.flush()

    profile = ProviderProfile(
        user_id=user.id,
        business_name=payload.business_name,
        city=payload.city,
        area=payload.area,
        address=payload.address,
        experience_years=payload.experience_years,
        description=payload.description,
        contact_phone=payload.contact_phone or payload.phone,
        whatsapp_number=payload.whatsapp_number,
        verification_status=VerificationStatus.PENDING.value,
    )
    db.add(profile)
    db.commit()
    db.refresh(user)

    return issue_tokens(db, user)


@router.post("/login", response_model=TokenResponse)
def login(
    payload: LoginRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    user = db.scalar(select(User).where(User.email == payload.email.lower()))

    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been deactivated. Contact support.",
        )

    return issue_tokens(db, user)


@router.post("/refresh", response_model=TokenResponse)
def refresh(
    payload: RefreshRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    try:
        claims = decode_token(payload.refresh_token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired. Please log in again.",
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    if claims.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    jti = claims.get("jti")
    stored = db.scalar(select(RefreshToken).where(RefreshToken.jti == jti))
    if (
        stored is None
        or stored.revoked
        or stored.expires_at < utcnow()
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token is no longer valid",
        )

    user = db.get(User, stored.user_id)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account is not available",
        )

    if claims.get("ver") != user.token_version:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has been revoked. Please log in again.",
        )

    # Rotate: the old refresh token can never be reused.
    stored.revoked = True
    db.commit()

    return issue_tokens(db, user)


@router.get("/me", response_model=UserPublic)
def me(current_user: User = Depends(get_current_user)) -> User:
    return current_user


@router.post("/logout", response_model=dict)
def logout(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    # Invalidate all sessions (all devices) and every issued access token.
    revoke_all_refresh_tokens(db, current_user.id, commit=False)
    current_user.token_version += 1
    db.commit()
    return {"message": "Logged out successfully"}


@router.post("/change-password", response_model=TokenResponse)
def change_password(
    payload: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TokenResponse:
    if not verify_password(
        payload.current_password, current_user.password_hash
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )

    if verify_password(payload.new_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from the current password",
        )

    current_user.password_hash = hash_password(payload.new_password)
    current_user.token_version += 1
    revoke_all_refresh_tokens(db, current_user.id, commit=False)
    db.commit()
    db.refresh(current_user)

    return issue_tokens(db, current_user)


@router.post(
    "/password-reset/request",
    response_model=PasswordResetResponse,
)
def request_password_reset(
    payload: PasswordResetRequest,
    db: Session = Depends(get_db),
) -> PasswordResetResponse:
    generic_message = (
        "If an account with that email exists, a password reset token "
        "has been generated."
    )

    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if user is None:
        return PasswordResetResponse(message=generic_message)

    # Invalidate any previously issued, unused reset tokens.
    db.execute(
        update(PasswordResetToken)
        .where(
            PasswordResetToken.user_id == user.id,
            PasswordResetToken.used.is_(False),
        )
        .values(used=True)
    )

    token = create_password_reset_token()
    db.add(
        PasswordResetToken(
            user_id=user.id,
            token_hash=hash_reset_token(token),
            expires_at=utcnow()
            + timedelta(minutes=settings.password_reset_expire_minutes),
        )
    )
    db.commit()

    response = PasswordResetResponse(message=generic_message)
    if settings.expose_reset_token:
        response.token = token
    return response


@router.post("/password-reset/confirm", response_model=dict)
def confirm_password_reset(
    payload: PasswordResetConfirm,
    db: Session = Depends(get_db),
) -> dict:
    token_hash = hash_reset_token(payload.token)
    reset_token = db.scalar(
        select(PasswordResetToken).where(
            PasswordResetToken.token_hash == token_hash
        )
    )

    if (
        reset_token is None
        or reset_token.used
        or reset_token.expires_at < utcnow()
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired password reset token",
        )

    user = db.get(User, reset_token.user_id)
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is not available",
        )

    user.password_hash = hash_password(payload.new_password)
    user.token_version += 1
    reset_token.used = True
    revoke_all_refresh_tokens(db, user.id, commit=False)
    db.commit()

    return {
        "message": "Password reset successfully. You can now log in with "
        "your new password."
    }
