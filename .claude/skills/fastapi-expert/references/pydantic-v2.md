# Pydantic V2 Schemas

## Model Configuration — `ConfigDict`

Always use `ConfigDict` — the V1 inner `class Config` is removed in V2.

```python
from pydantic import BaseModel, ConfigDict, EmailStr, Field

class UserBase(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,       # Replaces orm_mode=True
        populate_by_name=True,      # Allow field name OR alias
        str_strip_whitespace=True,  # Auto-strip string fields
        frozen=False,
    )
```

## Schema Patterns

```python
from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator
from typing import Self, Annotated
from pydantic import AfterValidator

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    username: str = Field(min_length=3, max_length=50)
    age: int = Field(ge=18, le=120)

    @field_validator("password", mode="after")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain an uppercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain a digit")
        return v

    @field_validator("username", mode="before")
    @classmethod
    def normalize_username(cls, v: str) -> str:
        if not v.isalnum():
            raise ValueError("Username must be alphanumeric")
        return v.lower()

class UserUpdate(BaseModel):
    email: EmailStr | None = None
    username: str | None = Field(None, min_length=3, max_length=50)
```

## Cross-Field Validation (`model_validator`)

```python
class PasswordReset(BaseModel):
    password: str
    password_confirm: str

    @model_validator(mode="after")
    def passwords_match(self) -> Self:
        if self.password != self.password_confirm:
            raise ValueError("Passwords do not match")
        return self
```

## ORM Mode — `from_attributes`

```python
class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    username: str
    is_active: bool
    created_at: datetime

# Use model_validate() (replaces V1's parse_obj/from_orm)
user_out = UserOut.model_validate(db_user)
```

## `computed_field` (New in V2)

Computed fields are included in `model_dump()` and `model_dump_json()` automatically.

```python
from pydantic import computed_field

class Rectangle(BaseModel):
    width: float
    height: float

    @computed_field
    @property
    def area(self) -> float:
        return self.width * self.height
```

## Annotated Validators — Reusable Constraints

Prefer `Annotated` validators for constraints shared across multiple models:

```python
from pydantic import AfterValidator, BeforeValidator
from typing import Annotated

def is_positive(v: int) -> int:
    if v <= 0:
        raise ValueError("Must be positive")
    return v

PositiveInt = Annotated[int, AfterValidator(is_positive)]
NormalizedStr = Annotated[str, BeforeValidator(str.strip)]

class Product(BaseModel):
    price: PositiveInt
    name: NormalizedStr
```

## Serialization Control

```python
class UserResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={"example": {"email": "user@example.com", "username": "johndoe"}},
    )

    id: int
    email: EmailStr
    password: str = Field(exclude=True)      # Never serialized
    internal_id: str = Field(repr=False)     # Hidden from repr

class ApiUser(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    user_id: int = Field(alias="userId", serialization_alias="user_id")
```

## Nested Models

```python
class Address(BaseModel):
    street: str
    city: str
    country: str = "US"

class UserWithAddress(BaseModel):
    name: str
    addresses: list[Address] = Field(default_factory=list)
```

## Settings (Pydantic Settings — separate package)

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    database_url: str
    secret_key: str
    redis_url: str = "redis://localhost:6379/0"
    environment: str = "production"
    cors_origins: list[str] = ["http://localhost:3000"]
    debug: bool = False

@lru_cache
def get_settings() -> Settings:
    return Settings()

# Inject as dependency
SettingsDep = Annotated[Settings, Depends(get_settings)]
```

## Quick Reference — V1 vs V2

| V1 Syntax | V2 Syntax |
|-----------|-----------|
| `@validator` | `@field_validator` |
| `@root_validator` | `@model_validator` |
| `class Config` | `model_config = ConfigDict(...)` |
| `orm_mode = True` | `from_attributes = True` |
| `Optional[X]` | `X \| None` |
| `.dict()` | `.model_dump()` |
| `.json()` | `.model_dump_json()` |
| `.parse_obj()` / `.from_orm()` | `.model_validate()` |
| No computed fields | `@computed_field @property` |
