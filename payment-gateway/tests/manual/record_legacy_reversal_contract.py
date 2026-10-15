"""Record the RA-00 legacy 0400 contract against the local processor.

Run from ``payment-gateway`` with the local processor already running::

    PYTHONPATH=. uv run python tests/manual/record_legacy_reversal_contract.py

The script only uses reserved STAN/ticket values 890001-890003 and deletes
rows with those exact identifiers before recording the scenarios.
"""

import json
import socket
import subprocess
from datetime import datetime
from typing import Any

from config.settings import Settings
from domain.authorization import AuthorizeCommand
from infrastructure.iso.message_builder import build_purchase_request
from infrastructure.iso.packer import IsoMessage, pack_iso, unpack_iso

_CARD_NUMBER = "6063007014007403"  # Synthetic card from the local demo seed.
_EXPIRATION = "1228"
_TERMINAL_ID = "05000001"
_PRODUCT_CODE = "993"
_AMOUNT_MINOR = 10_000
_RESERVED_IDS = ("890001", "890002", "890003")
_FIXED_MOMENT = datetime(2026, 10, 12, 12, 0, 0)


def _command(identifier: str) -> AuthorizeCommand:
    return AuthorizeCommand(
        product_code=_PRODUCT_CODE,
        amount_minor=_AMOUNT_MINOR,
        card_number=_CARD_NUMBER,
        terminal_id=_TERMINAL_ID,
        stan=identifier,
        ticket_number=identifier,
        expiration_date=_EXPIRATION,
    )


def _purchase(identifier: str, settings: Settings) -> IsoMessage:
    return build_purchase_request(
        _command(identifier),
        settings,
        now=_FIXED_MOMENT,
    )


def _reversal(identifier: str, settings: Settings) -> IsoMessage:
    message = _purchase(identifier, settings)
    message.mtype = "0400"
    return message


def _exchange(
    message: IsoMessage,
    settings: Settings,
) -> tuple[bytes, bytes, IsoMessage]:
    request = pack_iso(message)
    with socket.create_connection(
        (settings.iso_host, settings.iso_port),
        timeout=settings.iso_connect_timeout_seconds,
    ) as connection:
        connection.settimeout(settings.iso_read_timeout_seconds)
        connection.sendall(request)
        header = _recv_exact(connection, 2)
        length = (header[0] << 8) | header[1]
        response = header + _recv_exact(connection, length)
    return request, response, unpack_iso(response)


def _recv_exact(connection: socket.socket, size: int) -> bytes:
    chunks: list[bytes] = []
    remaining = size
    while remaining:
        chunk = connection.recv(remaining)
        if not chunk:
            raise ConnectionError("legacy processor closed the connection")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def _mysql(statement: str) -> str:
    result = subprocess.run(
        [
            "docker",
            "exec",
            "solidaridad-processor-mysql",
            "mysql",
            "-N",
            "-B",
            "-ukigadmin2",
            "-plocaldev",
            "kigsolidario2",
            "-e",
            statement,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def _clean_reserved_rows() -> None:
    identifiers = ", ".join(f"'{value}'" for value in _RESERVED_IDS)
    _mysql(
        "DELETE FROM sgas_cup "
        f"WHERE nro_tarjeta = '{_CARD_NUMBER}' "
        f"AND numero_comprobante IN ({identifiers}) "
        f"AND terminalid = '{_TERMINAL_ID}'"
    )


def _row_counts(identifier: str) -> dict[str, int]:
    output = _mysql(
        "SELECT tipo_mensaje, COUNT(*) FROM sgas_cup "
        f"WHERE nro_tarjeta = '{_CARD_NUMBER}' "
        f"AND numero_comprobante = '{identifier}' "
        f"AND terminalid = '{_TERMINAL_ID}' "
        "GROUP BY tipo_mensaje ORDER BY tipo_mensaje"
    )
    if not output:
        return {}
    return {
        message_type: int(count)
        for line in output.splitlines()
        for message_type, count in [line.split("\t")]
    }


def _capture(
    name: str,
    message: IsoMessage,
    settings: Settings,
) -> dict[str, Any]:
    request, response, parsed = _exchange(message, settings)
    return {
        "name": name,
        "request_hex": request.hex(),
        "response_hex": response.hex(),
        "response_mti": parsed.mtype,
        "response_code": parsed.respcode_39,
    }


def main() -> None:
    settings = Settings(
        iso_transport="tcp",
        iso_host="127.0.0.1",
        iso_port=4452,
    )
    _clean_reserved_rows()

    captures: list[dict[str, Any]] = []

    captures.append(_capture("existing_sale", _purchase("890001", settings), settings))
    captures.append(
        _capture("reversal_existing_sale", _reversal("890001", settings), settings)
    )
    captures[-1]["database_rows_after"] = _row_counts("890001")

    captures.append(
        _capture("reversal_missing_sale", _reversal("890002", settings), settings)
    )
    captures[-1]["database_rows_after"] = _row_counts("890002")

    captures.append(
        _capture("reversal_duplicate", _reversal("890001", settings), settings)
    )
    captures[-1]["database_rows_after"] = _row_counts("890001")

    captures.append(
        _capture("reversal_before_sale", _reversal("890003", settings), settings)
    )
    captures.append(
        _capture("sale_after_early_reversal", _purchase("890003", settings), settings)
    )
    captures[-1]["database_rows_after"] = _row_counts("890003")

    print(json.dumps({"captures": captures}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
