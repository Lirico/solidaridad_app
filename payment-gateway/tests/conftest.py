import os

# El proceso de test no trae .env. Sin transporte explícito el gateway no arranca.
os.environ.setdefault("APP_ENV", "local")
if os.environ["APP_ENV"].strip().lower() == "local":
    os.environ.setdefault("ISO_TRANSPORT", "mock")
else:
    os.environ.setdefault("ISO_TRANSPORT", "tcp")
