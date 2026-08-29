namespace :users do
  desc "Create the first tenant admin from ADMIN_* variables"
  task create_admin: :environment do
    user = Installation::BootstrapAdmin.call(ENV.to_h)
    puts "Bootstrap administrator created for organization #{user.organization.code}; immediate 2FA enrollment is required."
  rescue Installation::BootstrapAdmin::Refused => error
    abort "Admin bootstrap refused: #{error.message}"
  end
end
