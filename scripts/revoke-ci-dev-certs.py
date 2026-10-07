#!/usr/bin/env python3
"""Revokes the Apple Development certificates that this CI run created.

Archiving with cloud-managed signing (`-allowProvisioningUpdates` plus an App
Store Connect API key) creates a fresh "Apple Development" certificate on every
run, because each GitHub runner starts with an empty keychain. The private key
dies with the runner, so the certificate is useless afterwards. Left alone, the
certificates pile up until the team hits Apple's limit and archiving fails.

This script only revokes certificates whose serial number matches an
"Apple Development" certificate in this runner's keychain, so it can never touch
a developer's own certificates or any distribution certificate.

Usage: revoke-ci-dev-certs.py [--dry-run]
Environment: ASC_KEY_ID, ASC_ISSUER_ID; the key at ~/private_keys/AuthKey_<id>.p8.
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"


def keychain_dev_serials():
    """Serial numbers (upper-case hex, no leading zeros) of Apple Development certs in the keychains."""
    out = subprocess.run(
        ["security", "find-certificate", "-a", "-c", "Apple Development", "-p"],
        capture_output=True, text=True,
    ).stdout
    serials = set()
    for pem in re.findall(r"-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----", out, re.S):
        res = subprocess.run(
            ["openssl", "x509", "-noout", "-serial"], input=pem, capture_output=True, text=True
        )
        match = re.search(r"serial=([0-9A-Fa-f]+)", res.stdout)
        if match:
            serials.add(normalise(match.group(1)))
    return serials


def normalise(serial):
    return serial.upper().lstrip("0") or "0"


def matching_certificates(certificates, serials):
    """The App Store Connect certificates to revoke: development ones whose serial is local."""
    picked = []
    for cert in certificates:
        attrs = cert.get("attributes", {})
        if attrs.get("certificateType") not in ("DEVELOPMENT", "IOS_DEVELOPMENT"):
            continue
        if normalise(attrs.get("serialNumber", "")) in serials:
            picked.append(cert)
    return picked


def token():
    import jwt  # PyJWT, installed by the workflow step

    key_id = os.environ["ASC_KEY_ID"]
    with open(os.path.expanduser(f"~/private_keys/AuthKey_{key_id}.p8")) as handle:
        private_key = handle.read()
    now = int(time.time())
    payload = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


def request(method, url, auth):
    req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {auth}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = resp.read()
        return json.loads(body) if body else None


def main():
    dry_run = "--dry-run" in sys.argv
    serials = keychain_dev_serials()
    if not serials:
        print("No Apple Development certificate in this runner's keychain; nothing to revoke.")
        return 0
    auth = token()
    url = f"{API}/certificates?filter[certificateType]=DEVELOPMENT,IOS_DEVELOPMENT&limit=200"
    certificates = []
    while url:
        page = request("GET", url, auth)
        certificates += page.get("data", [])
        url = page.get("links", {}).get("next")
    for cert in matching_certificates(certificates, serials):
        name = cert["attributes"].get("name", "")
        if dry_run:
            print(f"Would revoke {cert['id']} ({name})")
        else:
            request("DELETE", f"{API}/certificates/{cert['id']}", auth)
            print(f"Revoked {cert['id']} ({name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
