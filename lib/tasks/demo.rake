namespace :demo do
  desc "Create or update the isolated portfolio demo dataset"
  task seed: :environment do
    manifest = DemoData::Seeder.call
    puts "Demo data ready: #{manifest.to_h.map { |name, count| "#{name}=#{count}" }.join(', ')}"
  rescue DemoData::Seeder::Refused => error
    abort "Demo seed refused: #{error.message}"
  end
end
