"""Keep external HTTP integration tests out of the unit-test gate by default."""

import os
from pathlib import Path

from _pytest.config import Config

# Importing the app calls get_settings(). CI has no .env, so APP_ENV has to be
# explicit before collection or startup refuses the implicit local default.
os.environ["APP_ENV"] = "local"


def pytest_ignore_collect(collection_path: Path, config: Config) -> bool:
    del config
    return (
        "tests/integration" in collection_path.as_posix()
        and os.environ.get("INTEGRATION_TESTS") != "1"
    )
