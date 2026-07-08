// EmailValidator.java
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.regex.*;

public class EmailValidator {
    private static final Set<String> DISPOSABLE_DOMAINS = new HashSet<>(Arrays.asList(
        "mailinator.com", "guerrillamail.com", "temp-mail.org", "10minutemail.com",
        "throwawaymail.com", "yopmail.com", "trashmail.com", "spamgourmet.com",
        "fakeinbox.com", "emailondeck.com", "gettemporaryemail.com", "sharklasers.com",
        "guerrillamail.net", "guerrillamail.org", "guerrillamail.biz", "mailnator.com",
        "spambox.us", "tempemail.net", "mailcatch.com", "mytrashmail.com",
        "trash2009.com", "trashdevil.com", "trashmail.net", "trashmail.org",
        "trashmail.ws", "trashmail.me", "trashmail.io", "tmpmail.org",
        "tmpmail.net", "tmpmail.com", "tempinbox.com", "tempemail.org",
        "tempemail.com", "tempail.com", "tempmail.com", "tempmail.net",
        "tempmail.org", "tempmail.biz", "tempmail.info", "tempmail.io",
        "tempmail.me", "tempmail.us", "tempmail.ws", "tempmail.co",
        "tempmail.co.uk", "tempmail.de", "tempmail.fr"
    ));

    private boolean checkDomain;
    private int total, valid, invalid;
    private Pattern emailPattern;

    public EmailValidator(boolean checkDomain) {
        this.checkDomain = checkDomain;
        this.total = 0;
        this.valid = 0;
        this.invalid = 0;
        this.emailPattern = Pattern.compile(
            "^(?<local>[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+)@(?<domain>[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$"
        );
    }

    public boolean isCheckDomain() { return checkDomain; }
    public void setCheckDomain(boolean val) { checkDomain = val; }

    public String[] getStats() {
        return new String[]{"Total: " + total, "Valid: " + valid, "Invalid: " + invalid};
    }

    public Result validateSyntax(String email) {
        if (email == null || email.isEmpty() || email.length() > 254)
            return new Result(false, "Empty or too long (>254)");
        Matcher m = emailPattern.matcher(email);
        if (!m.matches())
            return new Result(false, "Invalid format");
        String local = m.group("local");
        String domain = m.group("domain");
        if (local.length() > 64)
            return new Result(false, "Local part too long (>64)");
        if (local.contains("..") || local.startsWith(".") || local.endsWith("."))
            return new Result(false, "Invalid local part (dots)");
        if (!domain.contains("."))
            return new Result(false, "Domain must contain a dot");
        for (String label : domain.split("\\.")) {
            if (label.length() > 63 || label.isEmpty())
                return new Result(false, "Invalid domain label");
        }
        return new Result(true, "Syntax OK");
    }

    public boolean domainExists(String domain) {
        if (!checkDomain) return true;
        try {
            InetAddress[] addrs = InetAddress.getAllByName(domain);
            return addrs.length > 0;
        } catch (UnknownHostException e) {
            return false;
        }
    }

    public boolean isDisposable(String domain) {
        return DISPOSABLE_DOMAINS.contains(domain.toLowerCase());
    }

    public Result validate(String email) {
        total++;
        Result syntax = validateSyntax(email);
        if (!syntax.valid) {
            invalid++;
            return new Result(false, "Syntax error: " + syntax.reason);
        }
        String domain = email.split("@")[1].toLowerCase();
        if (isDisposable(domain)) {
            invalid++;
            return new Result(false, "Disposable email domain detected");
        }
        if (!domainExists(domain)) {
            invalid++;
            return new Result(false, "Domain does not exist (no A/MX record)");
        }
        valid++;
        return new Result(true, "Valid email");
    }

    public List<Result> batchValidate(String[] emails) {
        List<Result> results = new ArrayList<>();
        for (String email : emails) {
            email = email.trim();
            if (email.isEmpty()) continue;
            Result r = validate(email);
            results.add(new Result(r.valid, r.reason, email));
        }
        return results;
    }

    public void showStats() {
        System.out.printf("\nStatistics: Total: %d, Valid: %d, Invalid: %d\n", total, valid, invalid);
    }

    static class Result {
        boolean valid;
        String reason;
        String email; // optional for batch
        Result(boolean v, String r) { valid = v; reason = r; }
        Result(boolean v, String r, String e) { valid = v; reason = r; email = e; }
    }

    public static void main(String[] args) throws IOException {
        EmailValidator validator = new EmailValidator(true);
        BufferedReader reader = new BufferedReader(new InputStreamReader(System.in));
        System.out.println("=== Email Validator ===");
        while (true) {
            System.out.println("\n1. Validate single email");
            System.out.println("2. Validate from file");
            System.out.println("3. Show statistics");
            System.out.printf("4. Toggle domain validation (currently %s)\n", validator.isCheckDomain() ? "ON" : "OFF");
            System.out.println("5. Exit");
            System.out.print("Choose: ");
            String choice = reader.readLine().trim();
            switch (choice) {
                case "1":
                    System.out.print("Enter email: ");
                    String email = reader.readLine().trim();
                    Result res = validator.validate(email);
                    System.out.println("Valid: " + res.valid);
                    System.out.println("Details: " + res.reason);
                    break;
                case "2":
                    System.out.print("Enter file path: ");
                    String fname = reader.readLine().trim();
                    File file = new File(fname);
                    if (!file.exists()) {
                        System.out.println("File not found.");
                        break;
                    }
                    List<String> lines = new ArrayList<>();
                    try (BufferedReader br = new BufferedReader(new FileReader(file))) {
                        String line;
                        while ((line = br.readLine()) != null) {
                            lines.add(line);
                        }
                    }
                    String[] arr = lines.toArray(new String[0]);
                    List<Result> batch = validator.batchValidate(arr);
                    System.out.println("\nBatch results:");
                    for (Result r : batch) {
                        String status = r.valid ? "✓" : "✗";
                        System.out.printf("%s %s: %s\n", status, r.email, r.reason);
                    }
                    break;
                case "3":
                    validator.showStats();
                    break;
                case "4":
                    validator.setCheckDomain(!validator.isCheckDomain());
                    System.out.println("Domain validation toggled.");
                    break;
                case "5":
                    System.out.println("Goodbye!");
                    return;
                default:
                    System.out.println("Invalid choice.");
            }
        }
    }
}
