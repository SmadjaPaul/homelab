import requests
import pytest
from tenacity import retry, stop_after_attempt, wait_fixed


@retry(stop=stop_after_attempt(5), wait=wait_fixed(5))
def _check_url(url, allowed_codes):
    """Internal helper to check an endpoint with retries."""
    try:
        # verify=False because we might be using internal certs or just want to check availability
        resp = requests.get(
            url,
            headers={"User-Agent": "homelab-test/1.0"},
            timeout=10,
            verify=False,
            allow_redirects=False,
        )
        status = resp.status_code
    except requests.exceptions.RequestException as e:
        # Re-raise for tenacity to retry
        raise e

    assert status in allowed_codes, (
        f"Endpoint {url} returned {status}, expected one of {allowed_codes}"
    )
    return status


def test_http_endpoint_responds(test_case):
    """Verify that each public/protected endpoint returns 200/302/401."""
    if not test_case.hostname:
        pytest.skip(f"No hostname for {test_case.name}")

    url = f"https://{test_case.hostname}"
    # We allow 401 if it's protected by Authentik
    allowed_codes = [200, 302, 401]

    try:
        _check_url(url, allowed_codes)
    except Exception as e:
        pytest.fail(f"Could not reach {url} after retries: {e}")


def test_expected_endpoints(test_case):
    """Verify that manually specified expected endpoints are reachable."""
    if not test_case.test.expected_endpoints:
        pytest.skip(f"No expected endpoints for {test_case.name}")

    allowed_codes = [200, 302, 401]

    for url in test_case.test.expected_endpoints:
        try:
            _check_url(url, allowed_codes)
        except Exception as e:
            pytest.fail(f"Expected endpoint {url} unreachable after retries: {e}")
