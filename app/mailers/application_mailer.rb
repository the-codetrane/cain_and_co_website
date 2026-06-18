class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Cain & Co. <hello@cainandco.com>")
  layout "mailer"
end
