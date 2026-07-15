"""Domain exceptions for auth and identity."""


class DomainError(Exception):
    """Base class for expected domain failures."""


class EmailAlreadyExists(DomainError):
    """Raised when registering with an email that is already taken."""

    def __init__(self, email: str) -> None:
        self.email = email
        super().__init__("El email ya está registrado")


class WeakPassword(DomainError):
    """Raised when a password does not meet the policy."""

    def __init__(
        self,
        message: str = "La contraseña debe tener al menos 8 caracteres",
    ) -> None:
        super().__init__(message)


class InvalidInstallationId(DomainError):
    """Raised when installation_id is missing or invalid."""

    def __init__(
        self,
        message: str = "installation_id es requerido",
    ) -> None:
        super().__init__(message)
