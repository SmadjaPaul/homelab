"""
Dynamic routing tests.
Automatically discovered from apps.yaml.
"""
import urllib.request
import urllib.error
import pytest

def test_http_endpoint_responds(test_case):
    """Verify that each public/protected endpoint returns 200/302/401."""
    if not test_case.hostname:
        pytest.skip(f"No hostname for {test_case.name}")

    url = f"https://{test_case.hostname}"

    # We allow 401 if it's protected by Authentik
    allowed_codes = [200, 302, 401]

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "homelab-test/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            status = resp.status
    except urllib.error.HTTPError as e:
        status = e.code
    except Exception as e:
        pytest.fail(f"Could not reach {url}: {e}")

    assert status in allowed_codes, f"Endpoint {url} returned {status}, expected one of {allowed_codes}"

def test_expected_endpoints(test_case):
    """Verify that manually specified expected endpoints are reachable."""
    for url in test_case.test.expected_endpoints:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "homelab-test/1.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                status = resp.status
        except urllib.error.HTTPError as e:
            status = e.code
        except Exception as e:
            pytest.fail(f"Expected endpoint {url} unreachable: {e}")

        assert status in [200, 302, 401], f"Expected endpoint {url} failed with status {status}"
