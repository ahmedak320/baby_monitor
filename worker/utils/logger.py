"""Logging configuration for the worker."""

import logging


def setup_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    """Create a named logger with standard formatting."""
    logger = logging.getLogger(name)
    logger.setLevel(level)
    return logger
