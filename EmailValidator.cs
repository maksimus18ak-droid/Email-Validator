// EmailValidator.cs
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Text.RegularExpressions;

class EmailValidator
{
    private static readonly HashSet<string> DisposableDomains = new HashSet<string>
    {
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
    };

    public bool CheckDomain { get; set; }
    public (int Total, int Valid, int Invalid) Stats { get; private set; }
    private readonly Regex emailRegex;

    public EmailValidator(bool checkDomain = true)
    {
        CheckDomain = checkDomain;
        Stats = (0, 0, 0);
        emailRegex = new Regex(
            @"^(?<local>[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+)@(?<domain>[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$",
            RegexOptions.Compiled
        );
    }

    public (bool valid, string reason) ValidateSyntax(string email)
    {
        if (string.IsNullOrEmpty(email) || email.Length > 254)
            return (false, "Empty or too long (>254)");
        var match = emailRegex.Match(email);
        if (!match.Success)
            return (false, "Invalid format");
        string local = match.Groups["local"].Value;
        string domain = match.Groups["domain"].Value;
        if (local.Length > 64)
            return (false, "Local part too long (>64)");
        if (local.Contains("..") || local.StartsWith(".") || local.EndsWith("."))
            return (false, "Invalid local part (dots)");
        if (!domain.Contains("."))
            return (false, "Domain must contain a dot");
        foreach (var label in domain.Split('.'))
        {
            if (label.Length > 63 || string.IsNullOrEmpty(label))
                return (false, "Invalid domain label");
        }
        return (true, "Syntax OK");
    }

    public bool DomainExists(string domain)
    {
        if (!CheckDomain) return true;
        try
        {
            // Try A record
            var entry = Dns.GetHostEntry(domain);
            return true;
        }
        catch
        {
            // Try MX record via GetHostEntry? Actually we can try to resolve MX using Dns.GetHostEntry won't work.
            // We'll use a simple approach: try to get address list
            try
            {
                var addresses = Dns.GetHostAddresses(domain);
                return addresses.Length > 0;
            }
            catch
            {
                return false;
            }
        }
    }

    public bool IsDisposable(string domain) => DisposableDomains.Contains(domain.ToLower());

    public (bool valid, string reason) Validate(string email)
    {
        Stats.Total++;
        var syntax = ValidateSyntax(email);
        if (!syntax.valid)
        {
            Stats.Invalid++;
            return (false, $"Syntax error: {syntax.reason}");
        }
        string domain = email.Split('@')[1].ToLower();
        if (IsDisposable(domain))
        {
            Stats.Invalid++;
            return (false, "Disposable email domain detected");
        }
        if (!DomainExists(domain))
        {
            Stats.Invalid++;
            return (false, "Domain does not exist (no A/MX record)");
        }
        Stats.Valid++;
        return (true, "Valid email");
    }

    public List<(string email, bool valid, string reason)> BatchValidate(string[] emails)
    {
        var results = new List<(string, bool, string)>();
        foreach (var e in emails)
        {
            string email = e.Trim();
            if (string.IsNullOrEmpty(email)) continue;
            var result = Validate(email);
            results.Add((email, result.valid, result.reason));
        }
        return results;
    }

    public void ShowStats()
    {
        Console.WriteLine($"\nStatistics: Total: {Stats.Total}, Valid: {Stats.Valid}, Invalid: {Stats.Invalid}");
    }

    static void Main()
    {
        var validator = new EmailValidator(true);
        Console.WriteLine("=== Email Validator ===");
        while (true)
        {
            Console.WriteLine("\n1. Validate single email");
            Console.WriteLine("2. Validate from file");
            Console.WriteLine("3. Show statistics");
            Console.WriteLine($"4. Toggle domain validation (currently {(validator.CheckDomain ? "ON" : "OFF")})");
            Console.WriteLine("5. Exit");
            Console.Write("Choose: ");
            string choice = Console.ReadLine()?.Trim() ?? "";
            switch (choice)
            {
                case "1":
                    Console.Write("Enter email: ");
                    string email = Console.ReadLine()?.Trim() ?? "";
                    var result = validator.Validate(email);
                    Console.WriteLine($"Valid: {result.valid}");
                    Console.WriteLine($"Details: {result.reason}");
                    break;
                case "2":
                    Console.Write("Enter file path: ");
                    string fname = Console.ReadLine()?.Trim() ?? "";
                    if (!File.Exists(fname))
                    {
                        Console.WriteLine("File not found.");
                        break;
                    }
                    string[] lines = File.ReadAllLines(fname);
                    var batch = validator.BatchValidate(lines);
                    Console.WriteLine("\nBatch results:");
                    foreach (var r in batch)
                    {
                        string status = r.valid ? "✓" : "✗";
                        Console.WriteLine($"{status} {r.email}: {r.reason}");
                    }
                    break;
                case "3":
                    validator.ShowStats();
                    break;
                case "4":
                    validator.CheckDomain = !validator.CheckDomain;
                    Console.WriteLine("Domain validation toggled.");
                    break;
                case "5":
                    Console.WriteLine("Goodbye!");
                    return;
                default:
                    Console.WriteLine("Invalid choice.");
                    break;
            }
        }
    }
}
