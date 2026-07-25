require "net/http"
require "json"
require "cgi"

# Transactional email for signup verification.
#
# Provider-agnostic at the call site; the only implemented backend is Resend
# (https://resend.com — 3,000 emails/month free). When RESEND_API_KEY is
# unset the mailer runs in "logged" mode: it writes the verification link to
# stderr and reports :logged, so the whole double-opt-in flow works locally
# and in tests without sending real mail. Flip it on in prod with:
#   fly secrets set RESEND_API_KEY=...   (and EMAIL_FROM=you@yourdomain)
#
# Note: with Resend's shared onboarding sender (onboarding@resend.dev) you can
# only deliver to your own account email until you verify a custom domain.
module Mailer
  DEFAULT_FROM = "AstroChart <onboarding@resend.dev>".freeze

  SUBJECTS = {
    "zh-TW" => "確認你的 AstroChart API 金鑰申請",
    "en"    => "Confirm your AstroChart API key request",
    "ja"    => "AstroChart API キー申請の確認",
    "ko"    => "AstroChart API 키 신청 확인",
  }.freeze

  # Returns :sent (provider accepted), :logged (no API key — dev mode),
  # or :error (provider rejected; details logged, never raised at callers).
  def self.send_verification(email:, link:, lang: "zh-TW")
    lang = "zh-TW" unless SUBJECTS.key?(lang)
    subject = SUBJECTS[lang]
    html = verification_html(link, lang)

    api_key = ENV["RESEND_API_KEY"].to_s
    if api_key.empty?
      warn "[Mailer] (logged mode — set RESEND_API_KEY to send) verify #{email}: #{link}"
      return :logged
    end

    deliver_resend(api_key: api_key, to: email, subject: subject, html: html)
  end

  def self.deliver_resend(api_key:, to:, subject:, html:)
    uri = URI("https://api.resend.com/emails")
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{api_key}"
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(
      "from" => ENV["EMAIL_FROM"].to_s.empty? ? DEFAULT_FROM : ENV["EMAIL_FROM"],
      "to" => [to],
      "subject" => subject,
      "html" => html
    )
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request(req)
    end
    return :sent if res.is_a?(Net::HTTPSuccess)

    warn "[Mailer] Resend error #{res.code}: #{res.body}"
    :error
  rescue StandardError => e
    warn "[Mailer] Resend exception: #{e.class}: #{e.message}"
    :error
  end

  BODY = {
    "zh-TW" => ["申請 AstroChart API 金鑰", "點擊下方按鈕確認你的信箱，我們就會發給你 API 金鑰：", "確認並取得金鑰", "若你沒有申請，請忽略這封信。連結 24 小時內有效。"],
    "en"    => ["AstroChart API key request", "Click the button below to confirm your email and we'll issue your API key:", "Confirm & get my key", "If you didn't request this, ignore this email. The link expires in 24 hours."],
    "ja"    => ["AstroChart API キーの申請", "下のボタンをクリックしてメールを確認すると、API キーが発行されます：", "確認してキーを取得", "心当たりがない場合はこのメールを無視してください。リンクは24時間有効です。"],
    "ko"    => ["AstroChart API 키 신청", "아래 버튼을 클릭해 이메일을 확인하면 API 키가 발급됩니다:", "확인하고 키 받기", "신청하지 않았다면 이 이메일을 무시하세요. 링크는 24시간 동안 유효합니다."],
  }.freeze

  def self.verification_html(link, lang)
    title, intro, button, footer = BODY.fetch(lang, BODY["zh-TW"])
    safe = CGI.escapeHTML(link)
    <<~HTML
      <div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1a1a2e">
        <h2 style="font-weight:600">#{title}</h2>
        <p>#{intro}</p>
        <p style="margin:28px 0">
          <a href="#{safe}" style="background:#d3b877;color:#201a08;text-decoration:none;padding:12px 22px;border-radius:8px;font-weight:600;display:inline-block">#{button}</a>
        </p>
        <p style="font-size:13px;color:#666;word-break:break-all">#{safe}</p>
        <p style="font-size:12px;color:#999;margin-top:24px">#{footer}</p>
      </div>
    HTML
  end
end
