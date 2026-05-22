def get_email_sender():
    def send(email: str, code: str) -> None:
        print(f"[OTP] {email} -> {code}")

    return send
