"""TCP client for authkig ISO8583."""

import socket

from config.settings import Settings
from domain.authorization import (
    AuthorizationResult,
    AuthorizationStatus,
    AuthorizeCommand,
    VoidCommand,
)
from domain.exceptions import (
    IsoPackError,
    ProcessorUnavailable,
    ProcessorUnreachable,
)
from infrastructure.iso.message_builder import (
    build_purchase_request,
    build_void_request,
)
from infrastructure.iso.packer import IsoMessage, pack_iso, unpack_iso
from infrastructure.iso.response_mapper import map_iso_response


class TcpIsoProcessor:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def authorize(self, command: AuthorizeCommand) -> AuthorizationResult:
        request = build_purchase_request(command, self._settings)
        return self._send(request)

    def void(self, command: VoidCommand) -> AuthorizationResult:
        request = build_void_request(command, self._settings)
        return self._send(request)

    def _send(self, request: IsoMessage) -> AuthorizationResult:
        try:
            frame = pack_iso(request)
        except (ValueError, UnicodeEncodeError) as exc:
            raise IsoPackError("No se pudo armar el mensaje ISO") from exc

        try:
            response_frame = self._exchange(frame)
        except (TimeoutError, OSError, ConnectionError) as exc:
            raise ProcessorUnavailable() from exc

        try:
            response = unpack_iso(response_frame)
        except IsoPackError:
            return AuthorizationResult(
                status=AuthorizationStatus.FAILED,
                response_code="96",
                user_message="Respuesta ISO inválida",
            )
        return map_iso_response(response)

    def _exchange(self, frame: bytes) -> bytes:
        host = self._settings.iso_host
        port = self._settings.iso_port
        connect_timeout = self._settings.iso_connect_timeout_seconds
        read_timeout = self._settings.iso_read_timeout_seconds

        try:
            connection = socket.create_connection(
                (host, port),
                timeout=connect_timeout,
            )
        except (TimeoutError, OSError, ConnectionError) as exc:
            raise ProcessorUnreachable() from exc

        with connection as sock:
            sock.settimeout(read_timeout)
            sock.sendall(frame)
            header = _recv_exact(sock, 2)
            length = (header[0] << 8) | header[1]
            body = _recv_exact(sock, length)
            return header + body


def _recv_exact(sock: socket.socket, size: int) -> bytes:
    chunks: list[bytes] = []
    remaining = size
    while remaining > 0:
        chunk = sock.recv(remaining)
        if not chunk:
            raise ConnectionError("Conexión cerrada por el procesador")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)
