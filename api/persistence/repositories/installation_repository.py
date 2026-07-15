"""Installation persistence repository."""

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from domain.installation import Installation
from persistence.models.installation import Installation as InstallationModel


def _to_domain(row: InstallationModel) -> Installation:
    return Installation(
        id=row.id,
        platform=row.platform,
        last_seen_at=row.last_seen_at,
        created_at=row.created_at,
    )


class InstallationRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get_by_id(self, installation_id: str) -> Installation | None:
        row = self._session.get(InstallationModel, installation_id)
        if row is None:
            return None
        return _to_domain(row)

    def upsert(
        self,
        installation_id: str,
        *,
        platform: str | None = None,
    ) -> Installation:
        now = datetime.now(UTC)
        row = self._session.get(InstallationModel, installation_id)
        if row is None:
            row = InstallationModel(
                id=installation_id,
                platform=platform,
                last_seen_at=now,
            )
            self._session.add(row)
        else:
            row.last_seen_at = now
            if platform is not None and row.platform is None:
                row.platform = platform
        self._session.flush()
        return _to_domain(row)
