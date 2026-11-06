"""Admin-only endpoints demonstrating role-based authorization."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import require_admin
from ..models import (
    ProviderProfile,
    User,
    UserRole,
    VerificationStatus,
)
from ..schemas import RoleUpdateRequest, StatusUpdateRequest, UserPublic
from ..session_service import revoke_all_refresh_tokens

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/stats")
def get_stats(
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> dict:
    total_users = db.scalar(select(func.count(User.id))) or 0
    total_customers = (
        db.scalar(
            select(func.count(User.id)).where(
                User.role == UserRole.CUSTOMER.value
            )
        )
        or 0
    )
    total_providers = (
        db.scalar(
            select(func.count(User.id)).where(
                User.role == UserRole.PROVIDER.value
            )
        )
        or 0
    )
    pending_providers = (
        db.scalar(
            select(func.count(ProviderProfile.id)).where(
                ProviderProfile.verification_status
                == VerificationStatus.PENDING.value
            )
        )
        or 0
    )

    return {
        "total_users": total_users,
        "total_customers": total_customers,
        "total_providers": total_providers,
        "pending_providers": pending_providers,
        # Placeholders for modules that are not part of the auth backend yet.
        "pending_ads": 0,
        "pending_reviews": 0,
        "open_complaints": 0,
    }


@router.get("/users", response_model=list[UserPublic])
def list_users(
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
    role: str | None = None,
) -> list[User]:
    query = select(User).order_by(User.id)
    if role:
        if role not in {item.value for item in UserRole}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid role filter",
            )
        query = query.where(User.role == role)
    return list(db.scalars(query).all())


@router.get("/users/{user_id}", response_model=UserPublic)
def get_user(
    user_id: int,
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    return user


@router.patch("/users/{user_id}/role", response_model=UserPublic)
def change_user_role(
    user_id: int,
    payload: RoleUpdateRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> User:
    if user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot change your own role",
        )

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    user.role = payload.role
    user.token_version += 1
    revoke_all_refresh_tokens(db, user.id, commit=False)
    db.commit()
    db.refresh(user)
    return user


@router.patch("/users/{user_id}/status", response_model=UserPublic)
def change_user_status(
    user_id: int,
    payload: StatusUpdateRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> User:
    if user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot change your own account status",
        )

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    user.is_active = payload.is_active
    if not payload.is_active:
        user.token_version += 1
        revoke_all_refresh_tokens(db, user.id, commit=False)
    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{user_id}", response_model=dict)
def delete_user(
    user_id: int,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> dict:
    if user_id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot delete your own account from the admin panel",
        )

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    email = user.email
    db.delete(user)
    db.commit()
    return {"message": f"User {email} deleted successfully"}
