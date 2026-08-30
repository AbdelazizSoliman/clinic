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

  desc "Create Solid Queue/Cache tables when they share the primary database"
  task solid_schemas: :environment do
    loaded = Installation::SolidSchemaLoader.call
    puts loaded.any? ? "Loaded background schema: #{loaded.join(', ')}." : "Background schema already present."
  end
end

# db:prepare loads db/schema.rb for the primary database but never creates the Solid
# Queue/Cache tables when queue and cache share the primary DATABASE_URL, so the
# supported installation command has to finish the job.
Rake::Task["db:prepare"].enhance { Rake::Task["installation:solid_schemas"].invoke } if Rake::Task.task_defined?("db:prepare")
