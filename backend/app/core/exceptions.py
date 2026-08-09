# Credenciales inválidas o cuenta inactiva.
class AuthenticationError(Exception):
    pass


# Ya existe una cuenta con ese email.
class EmailAlreadyRegisteredError(Exception):
    pass


# El device_id no corresponde a ningún dispositivo registrado.
class DeviceNotFoundError(Exception):
    pass


# El alert_id no corresponde a ninguna alerta guardada.
class AlertNotFoundError(Exception):
    pass


# El código o la matrícula del dispositivo ya está en uso por otro.
# Guarda el campo que chocó para que la API le diga al cliente cuál fue.
class DeviceAlreadyExistsError(Exception):
    def __init__(self, message: str, field: str) -> None:
        super().__init__(message)
        self.field = field
