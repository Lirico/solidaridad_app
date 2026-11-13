"""Structured log for a backlog of stranded authorization requests."""

import logging

logger = logging.getLogger(__name__)


def log_stale_pending_backlog(
    *,
    backlog: int,
    oldest_age_seconds: int,
    selected: int,
    limit: int,
) -> None:
    """Record how far behind the watchdog is, without sale or card data."""
    logger.info(
        "stale_pending_backlog",
        extra={
            "event_name": "stale_pending_backlog",
            "backlog": backlog,
            "oldest_age_seconds": oldest_age_seconds,
            "selected": selected,
            "limit": limit,
        },
    )
