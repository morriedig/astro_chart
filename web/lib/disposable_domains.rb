require "set"

# A small, hand-maintained blocklist of common disposable / throwaway email
# domains. Not exhaustive — it catches the obvious ones cheaply, with no
# third-party API. Extend as abuse appears.
module DisposableDomains
  SET = %w[
    mailinator.com guerrillamail.com guerrillamail.info sharklasers.com
    10minutemail.com 10minutemail.net temp-mail.org tempmail.com tempmailo.com
    yopmail.com yopmail.fr getnada.com nada.email dispostable.com
    throwawaymail.com trashmail.com trashmail.de mailnesia.com maildrop.cc
    fakeinbox.com fakemailgenerator.com mohmal.com mytemp.email emailondeck.com
    tempinbox.com moakt.com burnermail.io tmpmail.org tmpmail.net
    spam4.me grr.la mailcatch.com inboxbear.com harakirimail.com
    discard.email tempr.email luxusmail.org mailtemp.net
  ].to_set.freeze

  # true if the email's domain is a known disposable provider.
  def self.disposable?(email)
    domain = email.to_s.downcase.split("@").last
    return false if domain.nil? || domain.empty?

    SET.include?(domain)
  end
end
