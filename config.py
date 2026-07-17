from pathlib import Path
from dotenv import load_dotenv, find_dotenv
import os

# Load the nearest .env file
load_dotenv(find_dotenv())


def get_env(name, default=None):
    """
    Return the value of an environment variable as a string.

    Returns the default value if the variable is not defined.
    """
    return os.getenv(name, default)


def require_env(name):
    """
    Return the value of an environment variable as a string.

    Raises a RuntimeError if the variable is not defined.
    """
    value = os.getenv(name)
    if not value:
        raise RuntimeError(
            f"Required environment variable '{name}' is not set.\n"
            f"Please add it to your .env file."
        )
    return value


def get_path(name):
    """
    Return an environment variable as a pathlib.Path.

    Returns None if the variable is not defined.
    """
    value = os.getenv(name)
    return Path(value).expanduser() if value else None


def require_path(name):
    """
    Return an environment variable as a pathlib.Path.

    Raises a RuntimeError if the variable is not defined.
    """
    value = os.getenv(name)
    if not value:
        raise RuntimeError(
            f"Required environment variable '{name}' is not set.\n"
            f"Please add it to your .env file."
        )
    return Path(value).expanduser()


def get_path_list(name, separator=","):
    """
    Return a comma-separated list of paths.

    Example:
        MEZZ_SERVERS=/mnt/mezz1,/mnt/mezz2,/mnt/mezz3
    """
    value = os.getenv(name)
    if not value:
        return []

    return [
        Path(p.strip()).expanduser()
        for p in value.split(separator)
        if p.strip()
    ]