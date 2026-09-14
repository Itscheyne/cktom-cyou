#!/usr/bin/env python3
import sys
import json
import os
import string
import secrets
import base64
import hmac
import hashlib
import subprocess
import yaml

BROKER_KEY_FILE = os.path.expanduser("~/.hermes/broker_mac_key.bin")

def get_broker_key():
    if not os.path.exists(BROKER_KEY_FILE):
        os.makedirs(os.path.dirname(BROKER_KEY_FILE), exist_ok=True)
        with open(BROKER_KEY_FILE, "wb") as f:
            f.write(secrets.token_bytes(32))
    with open(BROKER_KEY_FILE, "rb") as f:
        return f.read()

def generate_secret(typ, spec):
    if typ == "password":
        length = spec.get("length", 32)
        charset = spec.get("charset", "alnum-symbol")
        chars = string.ascii_letters + string.digits
        if "symbol" in charset:
            chars += "!@#$%^&*()-_=+"
        if spec.get("exclude_ambiguous"):
            for c in "Il1O0":
                chars = chars.replace(c, "")
        return "".join(secrets.choice(chars) for _ in range(length))
    elif typ == "api_key" or typ == "token":
        length = spec.get("length", 32)
        return secrets.token_urlsafe(length)
    elif typ == "random_bytes":
        length = spec.get("length", 32)
        return base64.b64encode(secrets.token_bytes(length)).decode('utf-8')
    elif typ in ["rsa_keypair", "ed25519_keypair"]:
        # Mocked generation for demonstration as per API contract
        return f"-----BEGIN PRIVATE KEY-----\n{secrets.token_urlsafe(64)}\n-----END PRIVATE KEY-----"
    else:
        return secrets.token_urlsafe(32)

def main():
    try:
        req = json.load(sys.stdin)
    except Exception as e:
        print(json.dumps({"error": "400 invalid_request", "message": "Failed to parse JSON stdin"}))
        sys.exit(1)

    if req.get("action") != "secret.create":
        print(json.dumps({"error": "400 invalid_request", "message": "action must be secret.create"}))
        sys.exit(1)
        
    name = req.get("name")
    env = req.get("environment")
    typ = req.get("type", "password")
    spec = req.get("spec", {})
    idem_key = req.get("idempotency_key")
    on_conflict = req.get("on_conflict", "error")

    if not name or not env or not idem_key:
        print(json.dumps({"error": "400 invalid_request", "message": "Missing name, environment, or idempotency_key"}))
        sys.exit(1)

    if "value" in spec:
        print(json.dumps({"error": "400 invalid_spec", "message": "spec contains value-bearing field"}))
        sys.exit(1)

    sanitized_name = name.replace("/", "_")
    target_dir = os.path.join("secrets", env)
    filepath = os.path.join(target_dir, f"{sanitized_name}.secrets.yaml")

    if os.path.exists(filepath):
        with open(filepath, "r") as f:
            try:
                existing_data = yaml.safe_load(f)
            except yaml.YAMLError:
                existing_data = {}
        
        existing_idem = existing_data.get("idempotency_key_unencrypted")
        if existing_idem == idem_key:
            ref = {
                "backend": "sops",
                "uri": f"sops://{filepath}#secret_value",
                "name": name,
                "environment": env
            }
            print(json.dumps({
                "status": "exists",
                "reference": ref,
                "fingerprint": existing_data.get("fingerprint_unencrypted")
            }))
            sys.exit(0)
        else:
            if on_conflict != "new_version":
                print(json.dumps({
                    "error": "409 name_conflict",
                    "message": "name exists and idempotency_key differs, on_conflict not set to new_version"
                }))
                sys.exit(1)

    # Generate
    sec_val = generate_secret(typ, spec)
    
    # Calculate MAC
    mac = hmac.new(get_broker_key(), sec_val.encode('utf-8'), hashlib.sha256).hexdigest()
    fingerprint = f"sha256:{mac}"

    os.makedirs(target_dir, exist_ok=True)
    
    data_to_write = {
        "secret_value": sec_val,
        "idempotency_key_unencrypted": idem_key,
        "fingerprint_unencrypted": fingerprint,
        "name_unencrypted": name
    }
    
    with open(filepath, "w") as f:
        yaml.dump(data_to_write, f)
        
    # Encrypt
    try:
        subprocess.run(["sops", "--encrypt", "--in-place", filepath], check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        os.remove(filepath)
        print(json.dumps({
            "error": "502 store_unavailable",
            "message": "SOPS backend write failed",
            "details": e.stderr.decode('utf-8', errors='ignore')
        }))
        sys.exit(1)

    ref = {
        "backend": "sops",
        "uri": f"sops://{filepath}#secret_value",
        "name": name,
        "environment": env
    }
    print(json.dumps({
        "status": "created",
        "reference": ref,
        "fingerprint": fingerprint
    }))

if __name__ == "__main__":
    main()
