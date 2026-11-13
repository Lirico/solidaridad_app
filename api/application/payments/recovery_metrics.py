"""Operational counters for recovery jobs. No card data and no case list."""

from datetime import UTC, datetime

from domain.processor_job import ProcessorJobState
from persistence.repositories.processor_job_repository import RecoveryStateAggregate

UNRESOLVED_STATES = frozenset(
    {
        ProcessorJobState.READY,
        ProcessorJobState.PROCESSING,
        ProcessorJobState.RETRY,
        ProcessorJobState.MANUAL_REVIEW,
    }
)
RESOLVED_STATES = frozenset(
    {
        ProcessorJobState.COMPLETED,
        ProcessorJobState.CANCELLED,
    }
)


def summarize_recovery_metrics(
    aggregates: list[RecoveryStateAggregate],
    *,
    open_alerts: int,
    now: datetime,
) -> dict[str, object]:
    """Fill every job state, even when the queue has no row in that state."""
    by_state = {aggregate.state: aggregate for aggregate in aggregates}
    counts = {state.value: 0 for state in ProcessorJobState}
    oldest_created_at: datetime | None = None
    max_attempt_count = 0
    max_resolution_seconds: float | None = None

    for state in ProcessorJobState:
        aggregate = by_state.get(state.value)
        if aggregate is None:
            continue
        counts[state.value] = aggregate.job_count
        if state in UNRESOLVED_STATES:
            max_attempt_count = max(max_attempt_count, aggregate.max_attempt_count)
            created_at = aggregate.oldest_created_at
            if created_at is not None and (
                oldest_created_at is None or created_at < oldest_created_at
            ):
                oldest_created_at = created_at
        elif (
            state in RESOLVED_STATES
            and aggregate.max_resolution_seconds is not None
            and (
                max_resolution_seconds is None
                or aggregate.max_resolution_seconds > max_resolution_seconds
            )
        ):
            max_resolution_seconds = aggregate.max_resolution_seconds

    return {
        "jobs_by_state": counts,
        "oldest_unresolved_age_seconds": _age_seconds(oldest_created_at, now),
        "max_attempt_count": max_attempt_count,
        "max_resolution_seconds": (
            None
            if max_resolution_seconds is None
            else max(0, int(max_resolution_seconds))
        ),
        "open_alerts": open_alerts,
    }


def _age_seconds(created_at: datetime | None, now: datetime) -> int | None:
    if created_at is None:
        return None
    if created_at.tzinfo is None:
        moment = created_at.replace(tzinfo=UTC)
    else:
        moment = created_at
    observed = now if now.tzinfo is not None else now.replace(tzinfo=UTC)
    return max(0, int((observed - moment).total_seconds()))
