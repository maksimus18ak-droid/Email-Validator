// email_validator.js
const readline = require('readline');
const dns = require('dns');
const fs = require('fs');

const DISPOSABLE_DOMAINS = new Set([
    'mailinator.com', 'guerrillamail.com', 'temp-mail.org', '10minutemail.com',
    'throwawaymail.com', 'yopmail.com', 'trashmail.com', 'spamgourmet.com',
    'fakeinbox.com', 'emailondeck.com', 'gettemporaryemail.com', 'sharklasers.com',
    'guerrillamail.net', 'guerrillamail.org', 'guerrillamail.biz', 'mailnator.com',
    'spambox.us', 'tempemail.net', 'mailcatch.com', 'mytrashmail.com',
    'trash2009.com', 'trashdevil.com', 'trashmail.net', 'trashmail.org',
    'trashmail.ws', 'trashmail.me', 'trashmail.io', 'tmpmail.org',
    'tmpmail.net', 'tmpmail.com', 'tempinbox.com', 'tempemail.org',
    'tempemail.com', 'tempail.com', 'tempmail.com', 'tempmail.net',
    'tempmail.org', 'tempmail.biz', 'tempmail.info', 'tempmail.io',
    'tempmail.me', 'tempmail.us', 'tempmail.ws', 'tempmail.co',
    'tempmail.co.uk', 'tempmail.de', 'tempmail.fr'
]);

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function ask(question) {
    return new Promise(resolve => rl.question(question, resolve));
}

class EmailValidator {
    constructor(checkDomain = true) {
        this.checkDomain = checkDomain;
        this.stats = { total: 0, valid: 0, invalid: 0 };
        // Regex for RFC 5322-like validation
        this.emailRegex = /^(?<local>[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+)@(?<domain>[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$/;
    }

    validateSyntax(email) {
        if (!email || email.length > 254) {
            return { valid: false, reason: "Empty or too long (>254)" };
        }
        const match = email.match(this.emailRegex);
        if (!match) {
            return { valid: false, reason: "Invalid format" };
        }
        const local = match.groups.local;
        const domain = match.groups.domain;
        if (local.length > 64) {
            return { valid: false, reason: "Local part too long (>64)" };
        }
        if (local.includes('..') || local.startsWith('.') || local.endsWith('.')) {
            return { valid: false, reason: "Invalid local part (dots)" };
        }
        if (!domain.includes('.')) {
            return { valid: false, reason: "Domain must contain a dot" };
        }
        for (const label of domain.split('.')) {
            if (label.length > 63 || label === '') {
                return { valid: false, reason: "Invalid domain label" };
            }
        }
        return { valid: true, reason: "Syntax OK" };
    }

    domainExists(domain) {
        return new Promise((resolve) => {
            if (!this.checkDomain) {
                resolve(true);
                return;
            }
            // Try A record
            dns.lookup(domain, (err) => {
                if (!err) {
                    resolve(true);
                    return;
                }
                // Try MX record
                dns.resolveMx(domain, (err2) => {
                    resolve(!err2);
                });
            });
        });
    }

    isDisposable(domain) {
        return DISPOSABLE_DOMAINS.has(domain.toLowerCase());
    }

    async validate(email) {
        this.stats.total++;
        const syntax = this.validateSyntax(email);
        if (!syntax.valid) {
            this.stats.invalid++;
            return { valid: false, reason: `Syntax error: ${syntax.reason}` };
        }
        const domain = email.split('@')[1].toLowerCase();
        if (this.isDisposable(domain)) {
            this.stats.invalid++;
            return { valid: false, reason: "Disposable email domain detected" };
        }
        const exists = await this.domainExists(domain);
        if (!exists) {
            this.stats.invalid++;
            return { valid: false, reason: "Domain does not exist (no A/MX record)" };
        }
        this.stats.valid++;
        return { valid: true, reason: "Valid email" };
    }

    async batchValidate(emails) {
        const results = [];
        for (const email of emails) {
            const trimmed = email.trim();
            if (!trimmed) continue;
            const result = await this.validate(trimmed);
            results.push({ email: trimmed, ...result });
        }
        return results;
    }

    showStats() {
        console.log(`\nStatistics: Total: ${this.stats.total}, Valid: ${this.stats.valid}, Invalid: ${this.stats.invalid}`);
    }
}

async function main() {
    const validator = new EmailValidator(true);
    console.log("=== Email Validator ===");
    while (true) {
        console.log("\n1. Validate single email");
        console.log("2. Validate from file");
        console.log("3. Show statistics");
        console.log(`4. Toggle domain validation (currently ${validator.checkDomain ? 'ON' : 'OFF'})`);
        console.log("5. Exit");
        const choice = await ask("Choose: ");
        switch (choice.trim()) {
            case '1': {
                const email = await ask("Enter email: ");
                const result = await validator.validate(email.trim());
                console.log(`Valid: ${result.valid}`);
                console.log(`Details: ${result.reason}`);
                break;
            }
            case '2': {
                const fname = await ask("Enter file path: ");
                try {
                    const data = fs.readFileSync(fname, 'utf8');
                    const emails = data.split('\n');
                    const results = await validator.batchValidate(emails);
                    console.log("\nBatch results:");
                    for (const r of results) {
                        const status = r.valid ? '✓' : '✗';
                        console.log(`${status} ${r.email}: ${r.reason}`);
                    }
                } catch (e) {
                    console.log("File not found or error.");
                }
                break;
            }
            case '3':
                validator.showStats();
                break;
            case '4':
                validator.checkDomain = !validator.checkDomain;
                console.log("Domain validation toggled.");
                break;
            case '5':
                console.log("Goodbye!");
                rl.close();
                return;
            default:
                console.log("Invalid choice.");
        }
    }
}

main().catch(console.error);
