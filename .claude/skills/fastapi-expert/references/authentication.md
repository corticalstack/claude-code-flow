# Authentication

> **IMPORTANT**: Use `PyJWT` (`pip install PyJWT`). Do NOT use `python-jose` — it has CVE-2024-33663
> (algorithm confusion vulnerability with ECDSA keys) and has been abandoned since 2022.
> The FastAPI docs updated away from `python-jose` in 2024.

## JWT Token Creation (PyJWT)

```python
import jwt  # PyJWT — NOT python-jose
from datetime import datetime, timedelta, timezone
from app.config import get_settings

settings = get_settings()

def create_access_token(subject: str, expires_delta: timedelta | None = None) -> str:
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=15))
    payload = {
        "sub": subject,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": "access",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")

def create_refresh_token(subject: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=7)
    payload = {"sub": subject, "exp": expire, "type": "refresh"}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")

def decode_token(token: str) -> dict:
    return jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
```

## Password Hashing

```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)
```

## OAuth2 Password Flow

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from typing import Annotated

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

@router.post("/token")
async def login(
    db: DB,
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
) -> Token:
    user = await authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return Token(
        access_token=create_access_token(subject=str(user.id)),
        token_type="bearer",
    )
```

## Get Current User (Annotated type alias pattern)

```python
from fastapi import Depends, HTTPException, status
from typing import Annotated

TokenDep = Annotated[str, Depends(oauth2_scheme)]

async def get_current_user(db: DB, token: TokenDep) -> User:
    credentials_exception = HTTPException(
        status.HTTP_401_UNAUTHORIZED,
        "Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise credentials_exception
        user_id = int(payload["sub"])
    except (jwt.InvalidTokenError, ValueError, TypeError):
        raise credentials_exception

    user = await get_user_db(db, user_id)
    if not user:
        raise credentials_exception
    return user

# Type alias — define once, use everywhere
CurrentUser = Annotated[User, Depends(get_current_user)]
```

## Role-Based Access Control

```python
from enum import StrEnum  # Python 3.11+

class UserRole(StrEnum):
    USER = "user"
    ADMIN = "admin"
    MODERATOR = "moderator"

def require_roles(*roles: UserRole):
    async def role_checker(current_user: CurrentUser) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                f"Required roles: {[r.value for r in roles]}",
            )
        return current_user
    return role_checker

AdminUser = Annotated[User, Depends(require_roles(UserRole.ADMIN))]

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(user_id: int, admin: AdminUser) -> None:
    ...
```

## Refresh Token Endpoint

```python
from fastapi import Body

@router.post("/refresh", response_model=Token)
async def refresh_token(
    db: DB,
    refresh_token: str = Body(..., embed=True),
) -> Token:
    try:
        payload = decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token type")
        user_id = int(payload["sub"])
    except (jwt.InvalidTokenError, ValueError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token")

    user = await get_user_db(db, user_id)
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found")

    return Token(
        access_token=create_access_token(subject=str(user.id)),
        token_type="bearer",
    )
```

## httpOnly Cookie Pattern (Recommended for SPAs)

Storing the refresh token in an httpOnly cookie protects it from XSS — JavaScript cannot read it.

```python
from fastapi import Response
from fastapi.responses import JSONResponse

@router.post("/auth/login")
async def login_with_cookie(db: DB, form_data: Annotated[OAuth2PasswordRequestForm, Depends()]) -> JSONResponse:
    user = await authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Incorrect credentials")

    access_token = create_access_token(subject=str(user.id), expires_delta=timedelta(minutes=15))
    refresh_token = create_refresh_token(subject=str(user.id))

    response = JSONResponse({"access_token": access_token, "token_type": "bearer"})
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,       # JS cannot read this
        secure=True,         # HTTPS only
        samesite="lax",      # CSRF protection
        max_age=7 * 24 * 3600,
    )
    return response

@router.post("/auth/refresh")
async def refresh_with_cookie(db: DB, refresh_token: str = Cookie(...)) -> JSONResponse:
    try:
        payload = decode_token(refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status.HTTP_401_UNAUTHORIZED)
        user = await get_user_db(db, int(payload["sub"]))
    except (jwt.InvalidTokenError, ValueError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token")

    access_token = create_access_token(subject=str(user.id))
    return JSONResponse({"access_token": access_token})
```

## Quick Reference

| Component | Purpose |
|-----------|---------|
| `PyJWT` (`import jwt`) | JWT encode/decode — replaces abandoned python-jose |
| `jwt.encode(payload, key, algorithm)` | Create JWT |
| `jwt.decode(token, key, algorithms=[...])` | Verify JWT (raises `jwt.InvalidTokenError`) |
| `jwt.InvalidTokenError` | Base exception for all JWT errors |
| `pwd_context.hash()` | Hash password with bcrypt |
| `pwd_context.verify()` | Check password against hash |
| `OAuth2PasswordBearer` | Extract token from Authorization header |
| `response.set_cookie(httponly=True, secure=True, samesite="lax")` | Secure refresh token cookie |
| `CurrentUser = Annotated[User, Depends(get_current_user)]` | Reusable auth dependency |
