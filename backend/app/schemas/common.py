from pydantic import BaseModel


# Clase para la respuesta de los endpoints /count.
class CountRead(BaseModel):
    count: int
