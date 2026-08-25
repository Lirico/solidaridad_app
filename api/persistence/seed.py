"""Idempotent local development seed.

Usage:
    uv run python -m persistence.seed
"""

import sys
from datetime import UTC, datetime
from typing import TypedDict

from pwdlib import PasswordHash
from sqlalchemy import select

from config import get_settings
from persistence.database import SessionLocal
from persistence.models import Installation, TerminalDevice, User


class DemoUser(TypedDict):
    name: str
    email: str
    password: str
    must_change_password: bool


DEMO_USERS: list[DemoUser] = [
    {
        "name": "Demo User",
        "email": "demo@solidaridad.local",
        "password": "demo1234",
        "must_change_password": False,
    },
    {
        "name": "Must Change User",
        "email": "mustchange@solidaridad.local",
        "password": "changeme1",
        "must_change_password": True,
    },
]

DEMO_INSTALLATION_ID = "05000001"
DEMO_INSTALLATION_PLATFORM = "local"
DEMO_LOGICAL_DEVICE_ID = "V660P-DEMO-0001"


password_hasher = PasswordHash.recommended()


def seed() -> None:
    settings = get_settings()
    if settings.app_env != "local":
        print(
            f"Refusing to seed: APP_ENV={settings.app_env!r} "
            "(only 'local' is allowed).",
            file=sys.stderr,
        )
        sys.exit(1)

    with SessionLocal() as session:
        for demo in DEMO_USERS:
            email = demo["email"].lower()
            existing = session.scalar(select(User).where(User.email == email))
            if existing is None:
                session.add(
                    User(
                        name=demo["name"],
                        email=email,
                        password_hash=password_hasher.hash(demo["password"]),
                        must_change_password=demo["must_change_password"],
                    )
                )
                print(f"Created user {email}")
            else:
                print(f"User {email} already exists — skipped")

        installation = session.scalar(
            select(Installation).where(
                Installation.installation_id == DEMO_INSTALLATION_ID
            )
        )
        now = datetime.now(UTC)
        if installation is None:
            session.add(
                Installation(
                    installation_id=DEMO_INSTALLATION_ID,
                    platform=DEMO_INSTALLATION_PLATFORM,
                    last_seen_at=now,
                )
            )
            print(f"Created installation {DEMO_INSTALLATION_ID}")
        else:
            installation.last_seen_at = now
            if installation.platform is None:
                installation.platform = DEMO_INSTALLATION_PLATFORM
            print(
                f"Installation {DEMO_INSTALLATION_ID} already exists "
                "— updated last_seen_at"
            )

        terminal = session.scalar(
            select(TerminalDevice).where(
                TerminalDevice.logical_device_id == DEMO_LOGICAL_DEVICE_ID
            )
        )
        if terminal is None:
            session.add(
                TerminalDevice(
                    logical_device_id=DEMO_LOGICAL_DEVICE_ID,
                    installation_id=DEMO_INSTALLATION_ID,
                )
            )
            print(f"Created terminal device {DEMO_LOGICAL_DEVICE_ID}")
        else:
            print(f"Terminal device {DEMO_LOGICAL_DEVICE_ID} already exists — skipped")

        session.commit()

    print("Seed completed.")


if __name__ == "__main__":
    seed()
