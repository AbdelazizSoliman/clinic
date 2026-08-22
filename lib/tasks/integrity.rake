namespace :integrity do
  { tenants: "Operations::TenantIntegrityCheck", inventory: "Operations::InventoryIntegrityCheck",
    financial: "Operations::FinancialIntegrityCheck" }.each do |name, checker_name|
    desc "Read-only #{name} integrity audit"
    task name => :environment do
      findings = checker_name.constantize.new.call
      findings.each { |finding| puts "#{finding.severity}: #{finding.code} count=#{finding.count} ids=#{finding.identifiers.join(',')}" }
      abort("#{name} integrity violations detected") if findings.any?
      puts "#{name} integrity: OK"
    end
  end
end
