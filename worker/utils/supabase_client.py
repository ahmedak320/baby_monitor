"""Supabase client for the worker."""

from supabase import create_client, Client
from config import settings


def get_supabase_client() -> Client:
    """Create and return a Supabase client using service role key."""
    return create_client(settings.supabase_url, settings.supabase_service_key)
