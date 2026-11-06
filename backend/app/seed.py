"""Seed demo accounts so the mobile app's quick-fill logins work out of the box."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import settings
from .database import SessionLocal
from .models import (
    ProviderProfile,
    User,
    UserRole,
    VerificationStatus,
)
from .security import hash_password

DEMO_CUSTOMER = {
    "email": "demo.customer1@example.com",
    "password": "CustomerPass123!",
    "full_name": "Demo Customer",
    "phone": "03001234567",
}

DEMO_PROVIDER = {
    "email": "zainwork0336@gmail.com",
    "password": "ProviderPass123!",
    "full_name": "Zain Work",
    "phone": "03007654321",
    "business_name": "Zain Work Services",
    "city": "Karachi",
    "area": "Gulshan-e-Iqbal",
    "experience_years": 5,
    "description": "Electrician, AC technician and home maintenance services.",
    "contact_phone": "03007654321",
    "whatsapp_number": "03007654321",
}


def _ensure_user(
    db: Session,
    *,
    email: str,
    password: str,
    full_name: str,
    role: str,
    phone: str | None = None,
) -> User:
    email = email.lower()
    user = db.scalar(select(User).where(User.email == email))
    if user is None:
        user = User(
            email=email,
            password_hash=hash_password(password),
            full_name=full_name,
            phone=phone,
            role=role,
            is_active=True,
        )
        db.add(user)
        db.flush()
    return user


def _ensure_provider_profile(db: Session, user: User) -> None:
    existing = db.scalar(
        select(ProviderProfile).where(ProviderProfile.user_id == user.id)
    )
    if existing is not None:
        return

    db.add(
        ProviderProfile(
            user_id=user.id,
            business_name=DEMO_PROVIDER["business_name"],
            city=DEMO_PROVIDER["city"],
            area=DEMO_PROVIDER["area"],
            experience_years=DEMO_PROVIDER["experience_years"],
            description=DEMO_PROVIDER["description"],
            contact_phone=DEMO_PROVIDER["contact_phone"],
            whatsapp_number=DEMO_PROVIDER["whatsapp_number"],
            verification_status=VerificationStatus.PENDING.value,
        )
    )


def seed_demo_data() -> None:
    db = SessionLocal()
    try:
        _ensure_user(
            db,
            email=settings.admin_email,
            password=settings.admin_password,
            full_name=settings.admin_full_name,
            role=UserRole.ADMIN.value,
        )
        _ensure_user(
            db,
            email=DEMO_CUSTOMER["email"],
            password=DEMO_CUSTOMER["password"],
            full_name=DEMO_CUSTOMER["full_name"],
            role=UserRole.CUSTOMER.value,
            phone=DEMO_CUSTOMER["phone"],
        )
        provider = _ensure_user(
            db,
            email=DEMO_PROVIDER["email"],
            password=DEMO_PROVIDER["password"],
            full_name=DEMO_PROVIDER["full_name"],
            role=UserRole.PROVIDER.value,
            phone=DEMO_PROVIDER["phone"],
        )
        _ensure_provider_profile(db, provider)
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
