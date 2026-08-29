require Rails.root.join("lib/installation/preflight")

namespace :installation do
  desc "Validate buyer installation environment without printing secrets"
  task :preflight do
    results = Installation::Preflight.new.call
    results.each { |result| puts "#{result.status.to_s.upcase} #{result.name}: #{result.message}" }
    failures = results.count { |result| result.status == :fail }
    abort "Preflight failed with #{failures} fatal problem(s)." if failures.positive?
    puts "PASS installation preflight: environment is ready for the supported boot path."
  end
end
