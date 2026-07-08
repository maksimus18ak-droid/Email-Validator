// email_validator.go
package main

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"regexp"
	"strings"
)

var disposableDomains = map[string]bool{
	"mailinator.com": true, "guerrillamail.com": true, "temp-mail.org": true,
	"10minutemail.com": true, "throwawaymail.com": true, "yopmail.com": true,
	"trashmail.com": true, "spamgourmet.com": true, "fakeinbox.com": true,
	"emailondeck.com": true, "gettemporaryemail.com": true, "sharklasers.com": true,
	"guerrillamail.net": true, "guerrillamail.org": true, "guerrillamail.biz": true,
	"mailnator.com": true, "spambox.us": true, "tempemail.net": true,
	"mailcatch.com": true, "mytrashmail.com": true, "trash2009.com": true,
	"trashdevil.com": true, "trashmail.net": true, "trashmail.org": true,
	"trashmail.ws": true, "trashmail.me": true, "trashmail.io": true,
	"tmpmail.org": true, "tmpmail.net": true, "tmpmail.com": true,
	"tempinbox.com": true, "tempemail.org": true, "tempemail.com": true,
	"tempail.com": true, "tempmail.com": true, "tempmail.net": true,
	"tempmail.org": true, "tempmail.biz": true, "tempmail.info": true,
	"tempmail.io": true, "tempmail.me": true, "tempmail.us": true,
	"tempmail.ws": true, "tempmail.co": true, "tempmail.co.uk": true,
	"tempmail.de": true, "tempmail.fr": true,
}

type EmailValidator struct {
	CheckDomain bool
	Stats       struct{ Total, Valid, Invalid int }
	regex       *regexp.Regexp
}

func NewEmailValidator(checkDomain bool) *EmailValidator {
	re := regexp.MustCompile(`^(?P<local>[a-zA-Z0-9.!#$%&'*+/=?^_` + "`" + `{|}~-]+)@(?P<domain>[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$`)
	return &EmailValidator{CheckDomain: checkDomain, regex: re}
}

func (v *EmailValidator) validateSyntax(email string) (bool, string) {
	if len(email) == 0 || len(email) > 254 {
		return false, "Empty or too long (>254)"
	}
	match := v.regex.FindStringSubmatch(email)
	if match == nil {
		return false, "Invalid format"
	}
	local := match[1]
	domain := match[2]
	if len(local) > 64 {
		return false, "Local part too long (>64)"
	}
	if strings.Contains(local, "..") || strings.HasPrefix(local, ".") || strings.HasSuffix(local, ".") {
		return false, "Invalid local part (dots)"
	}
	if !strings.Contains(domain, ".") {
		return false, "Domain must contain a dot"
	}
	for _, label := range strings.Split(domain, ".") {
		if len(label) > 63 || label == "" {
			return false, "Invalid domain label"
		}
	}
	return true, "Syntax OK"
}

func (v *EmailValidator) domainExists(domain string) bool {
	if !v.CheckDomain {
		return true
	}
	// Try A record
	if _, err := net.LookupHost(domain); err == nil {
		return true
	}
	// Try MX record
	if _, err := net.LookupMX(domain); err == nil {
		return true
	}
	return false
}

func (v *EmailValidator) isDisposable(domain string) bool {
	return disposableDomains[strings.ToLower(domain)]
}

func (v *EmailValidator) Validate(email string) (bool, string) {
	v.Stats.Total++
	syntaxOk, reason := v.validateSyntax(email)
	if !syntaxOk {
		v.Stats.Invalid++
		return false, "Syntax error: " + reason
	}
	domain := strings.ToLower(strings.Split(email, "@")[1])
	if v.isDisposable(domain) {
		v.Stats.Invalid++
		return false, "Disposable email domain detected"
	}
	if !v.domainExists(domain) {
		v.Stats.Invalid++
		return false, "Domain does not exist (no A/MX record)"
	}
	v.Stats.Valid++
	return true, "Valid email"
}

func (v *EmailValidator) BatchValidate(emails []string) []struct {
	Email  string
	Valid  bool
	Reason string
} {
	results := []struct {
		Email  string
		Valid  bool
		Reason string
	}{}
	for _, e := range emails {
		e = strings.TrimSpace(e)
		if e == "" {
			continue
		}
		valid, reason := v.Validate(e)
		results = append(results, struct {
			Email  string
			Valid  bool
			Reason string
		}{e, valid, reason})
	}
	return results
}

func (v *EmailValidator) ShowStats() {
	fmt.Printf("\nStatistics: Total: %d, Valid: %d, Invalid: %d\n", v.Stats.Total, v.Stats.Valid, v.Stats.Invalid)
}

func main() {
	validator := NewEmailValidator(true)
	scanner := bufio.NewScanner(os.Stdin)
	fmt.Println("=== Email Validator ===")
	for {
		fmt.Println("\n1. Validate single email")
		fmt.Println("2. Validate from file")
		fmt.Println("3. Show statistics")
		fmt.Printf("4. Toggle domain validation (currently %s)\n", map[bool]string{true: "ON", false: "OFF"}[validator.CheckDomain])
		fmt.Println("5. Exit")
		fmt.Print("Choose: ")
		scanner.Scan()
		choice := strings.TrimSpace(scanner.Text())
		switch choice {
		case "1":
			fmt.Print("Enter email: ")
			scanner.Scan()
			email := strings.TrimSpace(scanner.Text())
			valid, reason := validator.Validate(email)
			fmt.Printf("Valid: %v\n", valid)
			fmt.Printf("Details: %s\n", reason)
		case "2":
			fmt.Print("Enter file path: ")
			scanner.Scan()
			fname := strings.TrimSpace(scanner.Text())
			file, err := os.Open(fname)
			if err != nil {
				fmt.Println("File not found.")
				break
			}
			defer file.Close()
			var emails []string
			fileScanner := bufio.NewScanner(file)
			for fileScanner.Scan() {
				emails = append(emails, fileScanner.Text())
			}
			results := validator.BatchValidate(emails)
			fmt.Println("\nBatch results:")
			for _, r := range results {
				status := "✓"
				if !r.Valid {
					status = "✗"
				}
				fmt.Printf("%s %s: %s\n", status, r.Email, r.Reason)
			}
		case "3":
			validator.ShowStats()
		case "4":
			validator.CheckDomain = !validator.CheckDomain
			fmt.Println("Domain validation toggled.")
		case "5":
			fmt.Println("Goodbye!")
			return
		default:
			fmt.Println("Invalid choice.")
		}
	}
}
