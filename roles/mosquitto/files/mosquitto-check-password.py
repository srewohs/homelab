#!/usr/bin/env python3
"""Check a user's password against a mosquitto password file.

Usage: python3 mosquitto-check-password.py <password file> <user>, password
on stdin. The role runs it with python3 -c.
Exit 0 if it matches, 1 if the user is missing or the password differs or
uses another hash type, 2 on usage errors. Prints nothing about the hash.

Only the $7$ format (PBKDF2-SHA512, what mosquitto 2.x writes) is checked;
anything else counts as different, so the role rewrites it.
"""
import base64
import hashlib
import hmac
import sys


def main():
    if len(sys.argv) != 3:
        return 2
    path, user = sys.argv[1], sys.argv[2]
    password = sys.stdin.read().rstrip("\n").encode()
    try:
        with open(path) as f:
            lines = f.read().splitlines()
    except FileNotFoundError:
        return 1
    for line in lines:
        name, sep, entry = line.partition(":")
        if not sep or name != user:
            continue
        parts = entry.split("$")
        # "$7$<iterations>$<salt>$<hash>" splits to ['', '7', iter, salt, hash]
        if len(parts) != 5 or parts[1] != "7":
            return 1
        try:
            iterations = int(parts[2])
            salt = base64.b64decode(parts[3])
            expected = base64.b64decode(parts[4])
        except ValueError:
            return 1
        actual = hashlib.pbkdf2_hmac("sha512", password, salt, iterations, len(expected))
        return 0 if hmac.compare_digest(actual, expected) else 1
    return 1


if __name__ == "__main__":
    sys.exit(main())
