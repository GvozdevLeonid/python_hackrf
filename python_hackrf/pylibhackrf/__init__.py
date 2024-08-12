try:
    from . import pyhackrf_android as pyhackrf # noqa F401
except ImportError:
    from . import pyhackrf  # noqa F401
