"""Threaded runtime for durable recovery work owned by one API process."""

import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from threading import Event, Lock, Thread

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class RecoveryWorkerHealth:
    """Sanitized state exposed through the API readiness endpoint."""

    enabled: bool
    alive: bool
    stopping: bool
    started_at: datetime | None
    last_iteration_at: datetime | None
    last_error: str | None
    stale: bool = False

    @property
    def ready(self) -> bool:
        return not self.enabled or (self.alive and not self.stopping and not self.stale)


class EmbeddedRecoveryWorker:
    """Run one synchronous recovery iteration at a time in a dedicated thread.

    The iteration factory owns all request-unrelated resources, including its
    database session.  A failure is terminal for this loop: readiness becomes
    degraded instead of silently continuing with a partially working worker.
    """

    def __init__(
        self,
        *,
        run_iteration: Callable[[Callable[[], bool]], float],
        now: Callable[[], datetime] = lambda: datetime.now(UTC),
        enabled: bool = True,
        max_iteration_age_seconds: float = 30.0,
    ) -> None:
        self._run_iteration = run_iteration
        self._now = now
        self._enabled = enabled
        if max_iteration_age_seconds <= 0:
            raise ValueError("max_iteration_age_seconds must be positive")
        self._max_iteration_age_seconds = max_iteration_age_seconds
        self._stop_requested = Event()
        self._lock = Lock()
        self._thread: Thread | None = None
        self._started_at: datetime | None = None
        self._last_iteration_at: datetime | None = None
        self._last_error: str | None = None
        self._alive = False
        self._stopping = False

    def start(self) -> None:
        """Start exactly one loop for this FastAPI process."""
        if not self._enabled:
            return
        with self._lock:
            if self._thread is not None:
                raise RuntimeError("embedded recovery worker was already started")
            self._alive = True
            self._started_at = self._now()
            self._thread = Thread(
                target=self._run,
                name="embedded-recovery-worker",
                daemon=True,
            )
            self._thread.start()

    def stop(self, *, grace_seconds: float) -> bool:
        """Request shutdown and wait for the current iteration to finish."""
        if grace_seconds < 0:
            raise ValueError("grace_seconds must not be negative")
        self._stop_requested.set()
        with self._lock:
            self._stopping = True
            thread = self._thread
        if thread is None:
            return True
        thread.join(timeout=grace_seconds)
        stopped = not thread.is_alive()
        if not stopped:
            logger.error(
                "embedded_recovery_worker_shutdown_timeout",
                extra={"grace_seconds": grace_seconds},
            )
        return stopped

    def health(self) -> RecoveryWorkerHealth:
        with self._lock:
            latest_activity = self._last_iteration_at or self._started_at
            stale = (
                self._enabled
                and self._alive
                and latest_activity is not None
                and (self._now() - latest_activity).total_seconds()
                > self._max_iteration_age_seconds
            )
            return RecoveryWorkerHealth(
                enabled=self._enabled,
                alive=self._alive,
                stopping=self._stopping,
                started_at=self._started_at,
                last_iteration_at=self._last_iteration_at,
                last_error=self._last_error,
                stale=stale,
            )

    def stop_requested(self) -> bool:
        """Let an in-flight iteration decline to claim new work."""
        return self._stop_requested.is_set()

    def _run(self) -> None:
        try:
            while not self._stop_requested.is_set():
                poll_seconds = self._run_iteration(self.stop_requested)
                if poll_seconds <= 0:
                    raise ValueError(
                        "embedded recovery worker poll interval must be positive"
                    )
                with self._lock:
                    self._last_iteration_at = self._now()
                self._stop_requested.wait(timeout=poll_seconds)
        except Exception as exc:
            with self._lock:
                self._last_error = type(exc).__name__
            logger.exception(
                "embedded_recovery_worker_fatal",
                extra={"error_type": type(exc).__name__},
            )
        finally:
            with self._lock:
                self._alive = False
