from unittest.mock import MagicMock, patch

import pytest

from config.settings import Settings
from domain.authorization import AuthorizationStatus, AuthorizeCommand
from domain.exceptions import ProcessorUnavailable
from infrastructure.iso.packer import IsoMessage, pack_iso, set_present
from infrastructure.iso.tcp_processor import TcpIsoProcessor


def _cmd() -> AuthorizeCommand:
    return AuthorizeCommand(
        product_code="993",
        amount_minor=100,
        card_number="4111111111111111",
        terminal_id="TERM0001",
        stan="000001",
    )


def _approved_response_frame() -> bytes:
    iso = IsoMessage(
        tpdu="6000030000",
        mtype="0210",
        respcode_39="00",
        authid_38="AUTH01",
        retrefnum_37="123456789012",
        systracenum_11="000001",
    )
    set_present(iso, 11, 37, 38, 39)
    return pack_iso(iso)


def test_tcp_processor_maps_approved_response() -> None:
    settings = Settings(iso_transport="tcp")
    processor = TcpIsoProcessor(settings)
    frame = _approved_response_frame()

    with patch("infrastructure.iso.tcp_processor.socket.create_connection") as conn:
        sock = MagicMock()
        conn.return_value.__enter__.return_value = sock
        sock.recv.side_effect = [frame[:2], frame[2:]]
        result = processor.authorize(_cmd())

    assert result.status == AuthorizationStatus.APPROVED
    assert result.auth_id == "AUTH01"
    sock.sendall.assert_called_once()


def test_tcp_processor_failed_on_bad_response() -> None:
    settings = Settings(iso_transport="tcp")
    processor = TcpIsoProcessor(settings)
    with patch("infrastructure.iso.tcp_processor.socket.create_connection") as conn:
        sock = MagicMock()
        conn.return_value.__enter__.return_value = sock
        sock.recv.side_effect = [b"\x00\x02", b"\xff\xff"]
        result = processor.authorize(_cmd())
    assert result.status == AuthorizationStatus.FAILED


def test_tcp_processor_raises_unavailable_on_connect_error() -> None:
    settings = Settings(iso_transport="tcp")
    processor = TcpIsoProcessor(settings)
    with (
        patch(
            "infrastructure.iso.tcp_processor.socket.create_connection",
            side_effect=TimeoutError(),
        ),
        pytest.raises(ProcessorUnavailable),
    ):
        processor.authorize(_cmd())


def test_recv_exact_raises_on_closed_socket() -> None:
    from infrastructure.iso.tcp_processor import _recv_exact

    sock = MagicMock()
    sock.recv.return_value = b""
    with pytest.raises(ConnectionError):
        _recv_exact(sock, 4)


def test_dependencies_select_tcp() -> None:
    from infrastructure.iso.mock_processor import MockIsoProcessor
    from infrastructure.iso.tcp_processor import TcpIsoProcessor as Tcp
    from presentation.dependencies import get_iso_processor

    mock = get_iso_processor(Settings(iso_transport="mock"))
    tcp = get_iso_processor(Settings(iso_transport="tcp"))
    assert isinstance(mock, MockIsoProcessor)
    assert isinstance(tcp, Tcp)
