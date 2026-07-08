# email_validator.rb
require 'socket'
require 'resolv'

DISPOSABLE_DOMAINS = %w[
  mailinator.com guerrillamail.com temp-mail.org 10minutemail.com
  throwawaymail.com yopmail.com trashmail.com spamgourmet.com
  fakeinbox.com emailondeck.com gettemporaryemail.com sharklasers.com
  guerrillamail.net guerrillamail.org guerrillamail.biz mailnator.com
  spambox.us tempemail.net mailcatch.com mytrashmail.com
  trash2009.com trashdevil.com trashmail.net trashmail.org
  trashmail.ws trashmail.me trashmail.io tmpmail.org
  tmpmail.net tmpmail.com tempinbox.com tempemail.org
  tempemail.com tempail.com tempmail.com tempmail.net
  tempmail.org tempmail.biz tempmail.info tempmail.io
  tempmail.me tempmail.us tempmail.ws tempmail.co
  tempmail.co.uk tempmail.de tempmail.fr
].to_set

class EmailValidator
  attr_accessor :check_domain
  attr_reader :stats

  def initialize(check_domain = true)
    @check_domain = check_domain
    @stats = { total: 0, valid: 0, invalid: 0 }
    @email_regex = /^(?<local>[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+)@(?<domain>[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$/
  end

  def validate_syntax(email)
    return [false, "Empty or too long (>254)"] if email.nil? || email.empty? || email.length > 254
    match = email.match(@email_regex)
    return [false, "Invalid format"] unless match
    local = match[:local]
    domain = match[:domain]
    return [false, "Local part too long (>64)"] if local.length > 64
    return [false, "Invalid local part (dots)"] if local.include?('..') || local.start_with?('.') || local.end_with?('.')
    return [false, "Domain must contain a dot"] unless domain.include?('.')
    domain.split('.').each do |label|
      return [false, "Invalid domain label"] if label.length > 63 || label.empty?
    end
    [true, "Syntax OK"]
  end

  def domain_exists(domain)
    return true unless @check_domain
    # Try A record
    begin
      Socket.gethostbyname(domain)
      return true
    rescue SocketError
      # Try MX record using Resolv
      begin
        Resolv::DNS.open do |dns|
          mx = dns.getresource(domain, Resolv::DNS::Resource::IN::MX)
          return true if mx
        end
      rescue
        return false
      end
    end
  end

  def is_disposable?(domain)
    DISPOSABLE_DOMAINS.include?(domain.downcase)
  end

  def validate(email)
    @stats[:total] += 1
    syntax_ok, reason = validate_syntax(email)
    unless syntax_ok
      @stats[:invalid] += 1
      return [false, "Syntax error: #{reason}"]
    end
    domain = email.split('@')[1].downcase
    if is_disposable?(domain)
      @stats[:invalid] += 1
      return [false, "Disposable email domain detected"]
    end
    unless domain_exists(domain)
      @stats[:invalid] += 1
      return [false, "Domain does not exist (no A/MX record)"]
    end
    @stats[:valid] += 1
    [true, "Valid email"]
  end

  def batch_validate(emails)
    results = []
    emails.each do |e|
      email = e.strip
      next if email.empty?
      valid, reason = validate(email)
      results << { email: email, valid: valid, reason: reason }
    end
    results
  end

  def show_stats
    puts "\nStatistics: Total: #{@stats[:total]}, Valid: #{@stats[:valid]}, Invalid: #{@stats[:invalid]}"
  end
end

def main
  validator = EmailValidator.new(true)
  puts "=== Email Validator ==="
  loop do
    puts "\n1. Validate single email"
    puts "2. Validate from file"
    puts "3. Show statistics"
    puts "4. Toggle domain validation (currently #{validator.check_domain ? 'ON' : 'OFF'})"
    puts "5. Exit"
    print "Choose: "
    choice = gets.chomp.strip
    case choice
    when '1'
      print "Enter email: "
      email = gets.chomp.strip
      valid, reason = validator.validate(email)
      puts "Valid: #{valid}"
      puts "Details: #{reason}"
    when '2'
      print "Enter file path: "
      fname = gets.chomp.strip
      unless File.exist?(fname)
        puts "File not found."
        next
      end
      lines = File.readlines(fname).map(&:chomp)
      results = validator.batch_validate(lines)
      puts "\nBatch results:"
      results.each do |r|
        status = r[:valid] ? '✓' : '✗'
        puts "#{status} #{r[:email]}: #{r[:reason]}"
      end
    when '3'
      validator.show_stats
    when '4'
      validator.check_domain = !validator.check_domain
      puts "Domain validation toggled."
    when '5'
      puts "Goodbye!"
      break
    else
      puts "Invalid choice."
    end
  end
end

main if __FILE__ == $0
