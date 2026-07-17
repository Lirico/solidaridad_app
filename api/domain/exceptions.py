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


class InvalidCredentials(DomainError):
    """Raised on login failure without revealing whether the user exists."""

    def __init__(
        self,
        message: str = "Credenciales inválidas",
    ) -> None:
        super().__init__(message)


class InvalidCurrentPassword(DomainError):
    """Raised when change-password current_password does not match."""

    def __init__(
        self,
        message: str = "Contraseña actual incorrecta",
    ) -> None:
        super().__init__(message)


class UnsupportedProduct(DomainError):
    """Raised when the product code is not in the supported catalog."""

    def __init__(self, product: str = "") -> None:
        self.product = product
        super().__init__("Producto no soportado")


class InvalidAmount(DomainError):
    """Raised when amount is missing, non-positive, or has wrong scale."""

    def __init__(self, message: str = "Monto inválido") -> None:
        super().__init__(message)


class InvalidCardNumber(DomainError):
    """Raised when the PAN fails basic format/Luhn checks."""

    def __init__(self, message: str = "Número de tarjeta inválido") -> None:
        super().__init__(message)


class InvalidCvv(DomainError):
    """Raised when CVV is not 3 or 4 digits."""

    def __init__(self, message: str = "CVV inválido") -> None:
        super().__init__(message)


class MissingIdempotencyKey(DomainError):
    """Raised when Idempotency-Key header is absent."""

    def __init__(
        self,
        message: str = "Idempotency-Key es requerido",
    ) -> None:
        super().__init__(message)


class IdempotencyConflict(DomainError):
    """Raised when the same key is reused with a different payload."""

    def __init__(
        self,
        message: str = "Idempotency-Key ya usada con otro request",
    ) -> None:
        super().__init__(message)


class MissingTerminalId(DomainError):
    """Raised when the installation has no processor terminal configured."""

    def __init__(
        self,
        message: str = "La instalación no tiene terminal configurada",
    ) -> None:
        super().__init__(message)


class TransactionNumberExhausted(DomainError):
    """Raised when the daily transaction_number counter overflows."""

    def __init__(
        self,
        message: str = "Se alcanzó el límite diario de operaciones",
    ) -> None:
        super().__init__(message)
