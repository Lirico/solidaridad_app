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


class InvalidTicket(DomainError):
    def __init__(self, message: str = "número de comprobante inválido") -> None:
        super().__init__(message)


class UnsupportedProduct(DomainError):
    def __init__(self, product_code: str) -> None:
        self.product_code = product_code
        super().__init__(f"Producto no soportado: {product_code}")


class ProcessorUnavailable(DomainError):
    """Ambiguous failure: the message may have reached the processor."""

    def __init__(
        self,
        message: str = "Procesador de pagos no disponible",
    ) -> None:
        super().__init__(message)


class ProcessorUnreachable(ProcessorUnavailable):
    """No connection established: the message never left the gateway."""

    def __init__(
        self,
        message: str = "No se pudo conectar con el procesador de pagos",
    ) -> None:
        super().__init__(message)


class IsoPackError(DomainError):
    def __init__(
        self,
        message: str = "Error al armar o parsear mensaje ISO",
    ) -> None:
        super().__init__(message)
