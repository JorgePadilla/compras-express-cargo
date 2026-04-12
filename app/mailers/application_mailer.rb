class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "no-reply@comprasexpresscargo.com")
  layout "mailer"
end
