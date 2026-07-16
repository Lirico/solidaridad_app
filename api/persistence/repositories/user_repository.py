"""User persistence repository."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from domain.user import User
from persistence.models.user import User as UserModel


def _to_domain(row: UserModel) -> User:
    return User(
        id=row.id,
        name=row.name,
        email=row.email,
        password_hash=row.password_hash,
        must_change_password=row.must_change_password,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


class UserRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get_by_email(self, email: str) -> User | None:
        row = self._session.scalar(select(UserModel).where(UserModel.email == email))
        if row is None:
            return None
        return _to_domain(row)

    def get_by_id(self, user_id: UUID) -> User | None:
        row = self._session.get(UserModel, user_id)
        if row is None:
            return None
        return _to_domain(row)

    def create(
        self,
        *,
        name: str,
        email: str,
        password_hash: str,
        must_change_password: bool = False,
    ) -> User:
        row = UserModel(
            name=name,
            email=email,
            password_hash=password_hash,
            must_change_password=must_change_password,
        )
        self._session.add(row)
        self._session.flush()
        return _to_domain(row)

    def update_password(
        self,
        user_id: UUID,
        *,
        password_hash: str,
        must_change_password: bool = False,
    ) -> User | None:
        row = self._session.get(UserModel, user_id)
        if row is None:
            return None
        row.password_hash = password_hash
        row.must_change_password = must_change_password
        self._session.flush()
        return _to_domain(row)
