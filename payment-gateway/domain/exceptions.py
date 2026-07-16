"""Domain exceptions for the payment gateway."""


class DomainError(Exception):
    """Base class for expected domain failures."""


class InvalidAmount(DomainError):
    def __init__(self, message: str = "El monto debe ser mayor a cero") -> None:
        super().__init__(message)


class InvalidCardNumber(DomainError):
    def __init__(
        self,
        message: str = "Número de tarjeta inválido",
    ) -> None:
        super().__init__(message)


class InvalidTerminalId(DomainError):
    def __init__(self, message: str = "terminal_id es requerido") -> None:
        super().__init__(message)


class InvalidStan(DomainError):
    def __init__(self, message: str = "stan inválido") -> None:
        super().__init__(message)


class UnsupportedCurrency(DomainError):
    def __init__(self, currency: str) -> None:
        self.currency = currency
        super().__init__(f"Moneda no soportada: {currency}")


class ProcessorUnavailable(DomainError):
    def __init__(
        self,
        message: str = "Procesador de pagos no disponible",
    ) -> None:
        super().__init__(message)


class IsoPackError(DomainError):
    def __init__(
        self,
        message: str = "Error al armar o parsear mensaje ISO",
    ) -> None:
        super().__init__(message)
