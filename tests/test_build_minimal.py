"""
Minimal build test for Python 3.13 compatibility.
Tests core dependencies and basic functionality without complex imports.
"""

import pytest
import sys
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))


def test_core_dependencies():
    """Test that core dependencies can be imported."""
    try:
        import fastapi
        import uvicorn
        import pydantic
        import boto3
        import click
        import rich
        import jwt
        import bcrypt
        import httpx
        import yaml
        assert True, "Core dependencies imported successfully"
    except ImportError as e:
        pytest.fail(f"Failed to import core dependency: {e}")


def test_domain_models_import():
    """Test that simplified domain models can be imported."""
    try:
        from domain.models.application import Application, ApplicationStatus
        from domain.models.deployment import Deployment, DeploymentStatus
        from domain.models.resource import ResourceRequirements
        assert True, "Domain models imported successfully"
    except ImportError as e:
        pytest.fail(f"Failed to import domain models: {e}")


def test_fastapi_integration():
    """Test that FastAPI can be initialized with basic configuration."""
    try:
        from fastapi import FastAPI
        from api.main_simple import create_app
        
        app = create_app()
        assert isinstance(app, FastAPI)
        assert app.title == "AI-Native PaaS Platform"
        assert True, "FastAPI integration working"
    except Exception as e:
        pytest.fail(f"FastAPI integration failed: {e}")


def test_aws_sdk_basic():
    """Test that AWS SDK can be initialized."""
    try:
        import boto3
        from botocore.exceptions import NoCredentialsError
        
        # This should work even without credentials
        session = boto3.Session()
        assert session is not None
        assert True, "AWS SDK basic functionality working"
    except Exception as e:
        pytest.fail(f"AWS SDK basic test failed: {e}")


def test_configuration_management():
    """Test that configuration can be loaded."""
    try:
        from infrastructure.config.settings import Settings
        
        settings = Settings()
        assert settings is not None
        assert hasattr(settings, 'environment')
        assert True, "Configuration management working"
    except Exception as e:
        pytest.fail(f"Configuration management failed: {e}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
