# ✉️ Email Validator – Multi‑Language Edition

A robust **email validator** that performs deep syntax checks, domain validation (A/MX records), and detects disposable/temporary email addresses.  
Built in **7 programming languages** – ideal for learning or production use.

## ✨ Features
- **Syntax validation** – follows RFC 5322 rules (local part, domain, length, special characters, quoted strings, etc.).
- **Domain verification** – checks A or MX DNS records to ensure the domain exists (optional).
- **Disposable email detection** – built‑in list of 100+ known temporary email domains (e.g., `mailinator.com`, `guerrillamail.com`).
- **Batch processing** – validate multiple emails from a text file (one per line).
- **Statistics** – shows total, valid, and invalid counts.
- **Detailed error messages** – pinpoints why an email is invalid.
- **Interactive CLI** – easy‑to‑use menu.

## 🗂 Languages & Files
| Language          | File                   |
|-------------------|------------------------|
| Python            | `email_validator.py`   |
| Go                | `email_validator.go`   |
| JavaScript        | `email_validator.js`   |
| C#                | `EmailValidator.cs`    |
| Java              | `EmailValidator.java`  |
| Ruby              | `email_validator.rb`   |
| Swift             | `email_validator.swift`|

## 🚀 How to Run
Each file is standalone – run it with the appropriate interpreter/compiler:

| Language | Command |
|----------|---------|
| Python   | `python email_validator.py` |
| Go       | `go run email_validator.go` |
| JavaScript | `node email_validator.js` |
| C#       | `dotnet run` (or `csc EmailValidator.cs`) |
| Java     | `javac EmailValidator.java && java EmailValidator` |
| Ruby     | `ruby email_validator.rb` |
| Swift    | `swift email_validator.swift` |

> **Note**: Domain validation requires internet access and proper DNS configuration.  
> The built‑in disposable list is static – you can extend it in the code.

## 📊 Example Session
=== Email Validator ===

Validate single email

Validate from file

Show statistics

Toggle domain validation (ON)

Exit
Choose: 1

Enter email: test@example.com
Valid: true
Details: Domain exists (A record found)

Enter email: user@mailinator.com
Valid: false
Details: Disposable email domain detected

text

## 📁 Batch File Format
A plain text file with one email per line:
john.doe@gmail.com
jane@temp-mail.org
invalid-email

text
The validator processes each line and outputs results.

## 🔧 Technical Details
- **Syntax** – allows alphanumeric, dots, underscores, plus, hyphens in local part; domain must have at least one dot and valid TLD.
- **Domain check** – uses system DNS resolution (A or MX record).
- **Disposable list** – includes `mailinator.com`, `guerrillamail.com`, `temp-mail.org`, `10minutemail.com`, and many more.

## 🤝 Contributing
Add more disposable domains, improve DNS caching, or add internationalized email support – PRs welcome!

## 📜 License
MIT – use freely.
