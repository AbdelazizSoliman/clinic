class ApplicationMailer < ActionMailer::Base
  default from: -> { Mail::Address.new(ENV.fetch("MAIL_FROM_EMAIL", "no-reply@seydalety.local")).tap { |address| address.display_name = ENV.fetch("MAIL_FROM_NAME", "صيدليتي") }.format }
  layout "mailer"
end
