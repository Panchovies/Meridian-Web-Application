# Copyright (c) 2026 Francisco Zenklusen. All rights reserved.
"""Unit tests for the news endpoint of the Flask web service.

These tests verify that the /news endpoint returns:
    a status code of 200
    a JSON response containing the expected keys:
        status, totalResults, and articles
    as well as handling error cases such as missing query parameters
        or failed API requests.
"""
import os
from unittest.mock import Mock, patch

import requests
from src.app import app
from src.constants import (
    HTTP_STATUS_API_ERROR,
    HTTP_STATUS_BAD_REQUEST,
    HTTP_STATUS_INTERNAL_SERVER_ERROR,
    HTTP_STATUS_OK,
)


def test_news_status_code() -> None:
    """Verify that a valid news request returns HTTP 200."""
    client = app.test_client()

    mock_response = Mock()
    mock_response.raise_for_status.return_value = None
    mock_response.json.return_value = {
        "status": "ok",
        "totalResults": 1,
        "articles": ["article1"],
    }

    with patch.dict(os.environ, {"NEWS_API_KEY": "test_key"}), \
         patch("src.app.requests.get", return_value=mock_response):
        response = client.get("/news?q=apple")

    assert response.status_code == HTTP_STATUS_OK

def test_news_missing_query_parameter() -> None:
    """Verify that a request without the 'q' parameter returns HTTP 400."""
    client = app.test_client()
    mock_response = Mock()
    mock_response.raise_for_status.return_value = None
    mock_response.json.return_value = {
        "status": "ok",
        "totalResults": 1,
        "articles": ["article1"],
    }

    with patch.dict(os.environ, {"NEWS_API_KEY": "test_key"}), \
         patch("src.app.requests.get", return_value=mock_response):
        response = client.get("/news")
    assert response.status_code == HTTP_STATUS_BAD_REQUEST
    assert response.get_json() == {"Error":
                                   "Missing required query parameter 'q'"}

def test_news_missing_query_string() -> None:
    """Verify that a request with an empty 'q' parameter returns HTTP 400."""
    client = app.test_client()
    mock_response = Mock()
    mock_response.raise_for_status.return_value = None
    mock_response.json.return_value = {
        "status": "ok",
        "totalResults": 1,
        "articles": ["article1"],
    }

    with patch.dict(os.environ, {"NEWS_API_KEY": "test_key"}), \
         patch("src.app.requests.get", return_value=mock_response):
        response = client.get("/news?q=%20")
    assert response.status_code == HTTP_STATUS_BAD_REQUEST
    assert response.get_json() == {"Error":
                                   "Missing required query parameter 'q'"}

def test_news_api_failure() -> None:
    """Verify that a failed API request returns HTTP 500."""
    client = app.test_client()

    with patch.dict(os.environ, {"NEWS_API_KEY": "test_key"}), \
         patch("src.app.requests.get",
               side_effect=requests.RequestException("API failure")):
        response = client.get("/news?q=apple")

    assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR
    assert "Failed to fetch news articles" in response.get_json()["Error"]

def test_news_api_non_ok_status() -> None:
    """Verify that a non-ok API response returns HTTP 500."""
    client = app.test_client()

    mock_response = Mock()
    mock_response.raise_for_status.return_value = None
    mock_response.json.return_value = {
        "status": "error",
        "code": "apiKeyInvalid",
        "message": "Your API key is invalid or incorrect.",
    }

    with patch.dict(os.environ, {"NEWS_API_KEY": "test_key"}), \
         patch("src.app.requests.get", return_value=mock_response):
        response = client.get("/news?q=apple")

    assert response.status_code == HTTP_STATUS_INTERNAL_SERVER_ERROR
    assert response.get_json() == {"Error": "Failed to fetch news articles"}

def test_news_no_articles_found() -> None:
    """Verify that a request with no articles found returns HTTP 404."""
    client = app.test_client()

    mock_response = Mock()
    mock_response.raise_for_status.return_value = None
    mock_response.json.return_value = {
        "status": "ok",
        "totalResults": 0,
        "articles": [],
    }

    with patch.dict(os.environ, {"NEWS_API_KEY": "test_key"}), \
         patch("src.app.requests.get", return_value=mock_response):
        response = client.get("/news?q=nonexistentcompany")

    assert response.status_code == HTTP_STATUS_API_ERROR
    assert response.get_json() == {"Error": "No news articles "
        "found for query: nonexistentcompany"}
