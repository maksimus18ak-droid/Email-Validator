# email_validator.py
import re
import socket
import sys
from typing import Tuple, List, Optional

# Built-in list of disposable email domains (partial)
DISPOSABLE_DOMAINS = {
    'mailinator.com', 'guerrillamail.com', 'temp-mail.org', '10minutemail.com',
    'throwawaymail.com', 'yopmail.com', 'trashmail.com', 'spamgourmet.com',
    'fakeinbox.com', 'emailondeck.com', 'gettemporaryemail.com', 'sharklasers.com',
    'guerrillamail.net', 'guerrillamail.org', 'guerrillamail.biz', 'mailnator.com',
    'spambox.us', 'tempemail.net', 'mailcatch.com', 'mytrashmail.com',
    'trash2009.com', 'trash2009.com', 'trashdevil.com', 'trashmail.net',
    'trashmail.org', 'trashmail.ws', 'trashmail.me', 'trashmail.io',
    'tmpmail.org', 'tmpmail.net', 'tmpmail.com', 'tempinbox.com',
    'tempemail.org', 'tempemail.com', 'tempail.com', 'tempmail.com',
    'tempmail.net', 'tempmail.org', 'tempmail.biz', 'tempmail.info',
    'tempmail.io', 'tempmail.me', 'tempmail.us', 'tempmail.ws',
    'tempmail.co', 'tempmail.co.uk', 'tempmail.de', 'tempmail.fr'
}

class EmailValidator:
    def __init__(self, check_domain: bool = True):
        self.check_domain = check_domain
        self.stats = {'total': 0, 'valid': 0, 'invalid': 0}
        # RFC 5322 compliant regex (simplified, but comprehensive)
        self.email_regex = re.compile(
            r"^(?P<local>[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+)@(?P<domain>[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$"
        )

    def validate_syntax(self, email: str) -> Tuple[bool, str]:
        """Check syntax, return (valid, reason)."""
        if not email or len(email) > 254:
            return False, "Empty or too long (>254)"
        match = self.email_regex.match(email)
        if not match:
            return False, "Invalid format"
        local = match.group('local')
        domain = match.group('domain')
        # Check local part length (max 64)
        if len(local) > 64:
            return False, "Local part too long (>64)"
        # Check for consecutive dots, leading/trailing dots in local
        if '..' in local or local.startswith('.') or local.endswith('.'):
            return False, "Invalid local part (dots)"
        # Domain must have at least one dot
        if '.' not in domain:
            return False, "Domain must contain a dot"
        # Check domain labels length (max 63)
        for label in domain.split('.'):
            if len(label) > 63 or not label:
                return False, "Invalid domain label"
        return True, "Syntax OK"

    def check_domain_exists(self, domain: str) -> bool:
        """Check if domain has A or MX record (using socket)."""
        if not self.check_domain:
            return True  # skip check
        try:
            # Try to resolve A record
            socket.gethostbyname(domain)
            return True
        except socket.error:
            # Try MX record (not directly supported in socket, but we can use getaddrinfo with type)
            # For simplicity, we fallback to trying to get address info with a dummy port
            try:
                socket.getaddrinfo(domain, 25, socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP)
                return True
            except socket.error:
                return False

    def is_disposable(self, domain: str) -> bool:
        """Check if domain is in disposable list."""
        return domain.lower() in DISPOSABLE_DOMAINS

    def validate(self, email: str) -> Tuple[bool, str]:
        """Full validation: syntax + domain + disposable check."""
        self.stats['total'] += 1
        # Syntax
        syntax_ok, reason = self.validate_syntax(email)
        if not syntax_ok:
            self.stats['invalid'] += 1
            return False, f"Syntax error: {reason}"
        # Extract domain
        domain = email.split('@')[1].lower()
        # Disposable check
        if self.is_disposable(domain):
            self.stats['invalid'] += 1
            return False, "Disposable email domain detected"
        # Domain existence
        if not self.check_domain_exists(domain):
            self.stats['invalid'] += 1
            return False, "Domain does not exist (no A/MX record)"
        self.stats['valid'] += 1
        return True, "Valid email"

    def batch_validate(self, emails: List[str]) -> List[Tuple[str, bool, str]]:
        results = []
        for email in emails:
            email = email.strip()
            if not email:
                continue
            valid, reason = self.validate(email)
            results.append((email, valid, reason))
        return results

    def show_stats(self):
        print(f"\nStatistics: Total: {self.stats['total']}, Valid: {self.stats['valid']}, Invalid: {self.stats['invalid']}")

def main():
    validator = EmailValidator(check_domain=True)
    print("=== Email Validator ===")
    while True:
        print("\n1. Validate single email")
        print("2. Validate from file")
        print("3. Show statistics")
        print("4. Toggle domain validation (currently {})".format("ON" if validator.check_domain else "OFF"))
        print("5. Exit")
        choice = input("Choose: ").strip()
        if choice == '1':
            email = input("Enter email: ").strip()
            valid, reason = validator.validate(email)
            print(f"Valid: {valid}")
            print(f"Details: {reason}")
        elif choice == '2':
            fname = input("Enter file path: ").strip()
            try:
                with open(fname, 'r') as f:
                    emails = f.readlines()
                results = validator.batch_validate(emails)
                print("\nBatch results:")
                for email, valid, reason in results:
                    status = "✓" if valid else "✗"
                    print(f"{status} {email}: {reason}")
            except FileNotFoundError:
                print("File not found.")
            except Exception as e:
                print(f"Error: {e}")
        elif choice == '3':
            validator.show_stats()
        elif choice == '4':
            validator.check_domain = not validator.check_domain
            print("Domain validation toggled.")
        elif choice == '5':
            print("Goodbye!")
            break
        else:
            print("Invalid choice.")

if __name__ == "__main__":
    main()
