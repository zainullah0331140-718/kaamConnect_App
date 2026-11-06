"""Pydantic request/response schemas."""

import re
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from .models import UserRole


def _validate_password(value: str) -> str:
    if len(value) < 8:
        raise ValueError("Password must be at least 8 characters long")
    if not re.search(r"[A-Za-z]", value) or not re.search(r"\d", value):
        raise ValueError(
            "Password must contain at least one letter and one number"
        )
    return value


def _clean_optional(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    return value or None


class UserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    full_name: str
    phone: str | None = None
    profile_image: str | None = None
    role: str
    is_active: bool
    created_at: datetime | None = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class MessageResponse(BaseModel):
    message: str


# ---------------------------------------------------------------- registration


class RegisterCustomerRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str
    phone: str | None = None

    @field_validator("password")
    @classmethod
    def _password_policy(cls, value: str) -> str:
        return _validate_password(value)

    @field_validator("full_name")
    @classmethod
    def _clean_name(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 2:
            raise ValueError("Full name must be at least 2 characters")
        return value

    @field_validator("phone")
    @classmethod
    def _clean_phone(cls, value: str | None) -> str | None:
        return _clean_optional(value)


class RegisterProviderRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str
    business_name: str = Field(min_length=2, max_length=200)
    city: str = Field(min_length=2, max_length=100)
    area: str | None = None
    address: str | None = None
    experience_years: int = Field(default=0, ge=0, le=80)
    description: str | None = None
    phone: str | None = None
    contact_phone: str | None = None
    whatsapp_number: str | None = None

    @field_validator("password")
    @classmethod
    def _password_policy(cls, value: str) -> str:
        return _validate_password(value)

    @field_validator("full_name", "business_name", "city")
    @classmethod
    def _clean_required(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 2:
            raise ValueError("This field must be at least 2 characters")
        return value

    @field_validator("area", "address", "description", "phone",
                     "contact_phone", "whatsapp_number")
    @classmethod
    def _clean_optional_fields(cls, value: str | None) -> str | None:
        return _clean_optional(value)


# ----------------------------------------------------------------------- login


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=10)


# ------------------------------------------------------------------- passwords


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _validate_new_password(cls, value: str) -> str:
        return _validate_password(value)


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirm(BaseModel):
    token: str = Field(min_length=10)
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _validate_new_password(cls, value: str) -> str:
        return _validate_password(value)


class PasswordResetResponse(BaseModel):
    message: str
    token: str | None = None


# ------------------------------------------------------------------- account


class DeleteAccountRequest(BaseModel):
    password: str


# --------------------------------------------------------------------- admin


class RoleUpdateRequest(BaseModel):
    role: str

    @field_validator("role")
    @classmethod
    def _validate_role(cls, value: str) -> str:
        allowed = {item.value for item in UserRole}
        if value not in allowed:
            raise ValueError(f"Role must be one of: {', '.join(sorted(allowed))}")
        return value


class StatusUpdateRequest(BaseModel):
    is_active: bool
