"""AES-GCM for the PAN and expiry kept for recovery."""

import base64
import os

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

CARD_CIPHER_PREFIX = "v1."
_NONCE_SIZE = 12
_KEY_SIZE = 32


class CardCipherError(ValueError):
    """Stored card data cannot be decrypted. The message never includes the PAN."""


def is_legacy_plaintext(value: str) -> bool:
    """A PAN or expiry written before application encryption."""
    if not value.isdigit():
        return False
    return len(value) == 4 or 13 <= len(value) <= 19


class CardCipher:
    def __init__(self, key: bytes) -> None:
        if len(key) != _KEY_SIZE:
            raise CardCipherError("La clave de cifrado de tarjeta no tiene 32 bytes")
        self._aesgcm = AESGCM(key)

    def encrypt(self, plaintext: str) -> str:
        nonce = os.urandom(_NONCE_SIZE)
        ciphertext = self._aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)
        payload = base64.b64encode(nonce + ciphertext).decode("ascii")
        return f"{CARD_CIPHER_PREFIX}{payload}"

    def decrypt(self, stored: str) -> str:
        if is_legacy_plaintext(stored):
            return stored
        if not stored.startswith(CARD_CIPHER_PREFIX):
            raise CardCipherError("Dato de tarjeta irreconocible")
        try:
            raw = base64.b64decode(stored[len(CARD_CIPHER_PREFIX) :], validate=True)
            nonce = raw[:_NONCE_SIZE]
            ciphertext = raw[_NONCE_SIZE:]
            if len(nonce) != _NONCE_SIZE or not ciphertext:
                raise CardCipherError("Dato de tarjeta irreconocible")
            return self._aesgcm.decrypt(nonce, ciphertext, None).decode("utf-8")
        except CardCipherError:
            raise
        except (InvalidTag, ValueError, UnicodeDecodeError) as exc:
            raise CardCipherError("No se pudo descifrar el dato de tarjeta") from exc
