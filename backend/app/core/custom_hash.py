import random
import re
import secrets

ALLOWED_CHARSET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$"
PASSWORD_PATTERN = re.compile(r"^[a-zA-Z0-9#$]{8,12}$")


def _build_deterministic_dict() -> dict[str, tuple[str, str, str]]:
    """Build deterministic 64-char -> 3 unique 3-char codes mapping (192 unique codes total)."""
    rng = random.Random(20261128)
    used_codes: set[str] = set()
    mapping: dict[str, tuple[str, str, str]] = {}
    for ch in ALLOWED_CHARSET:
        codes: list[str] = []
        while len(codes) < 3:
            code = "".join(rng.choice(ALLOWED_CHARSET) for _ in range(3))
            if code not in used_codes:
                used_codes.add(code)
                codes.append(code)
        mapping[ch] = (codes[0], codes[1], codes[2])
    return mapping


CHAR_HASH_DICT: dict[str, tuple[str, str, str]] = _build_deterministic_dict()


def validate_password_format(raw_password: str) -> bool:
    return bool(PASSWORD_PATTERN.fullmatch(raw_password))


def encode_custom_hash(raw_password: str) -> str:
    if not validate_password_format(raw_password):
        raise ValueError("Password must be 8-12 chars using only a-z, A-Z, 0-9, #, $")
    return "".join(secrets.choice(CHAR_HASH_DICT[ch]) for ch in raw_password)


def verify_custom_hash(raw_password: str, stored_hash: str) -> bool:
    if not stored_hash or len(stored_hash) != len(raw_password) * 3:
        return False
    for idx, ch in enumerate(raw_password):
        chunk = stored_hash[idx * 3 : (idx + 1) * 3]
        allowed = CHAR_HASH_DICT.get(ch)
        if not allowed or chunk not in allowed:
            return False
    return True
