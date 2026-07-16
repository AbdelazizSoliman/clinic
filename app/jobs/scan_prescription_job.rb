class ScanPrescriptionJob < ApplicationJob
  queue_as :security
  retry_on Uploads::Scanner::ConfigurationError, wait: 30.minutes, attempts: 3

  def perform(prescription_id)
    prescription = Prescription.find(prescription_id)
    results = prescription.images.map { |attachment| Uploads::Scanner.call(attachment.blob) }
    status = results.all?(:clean) ? :clean : :infected
    prescription.update!(scan_status: status, scanned_at: Time.current, scan_failure_class: nil)
    SecurityEvent.record("prescription_scan_#{status}", user: prescription.user,
      metadata: { action: "prescription_scan" }) unless status == :clean
  rescue Uploads::Scanner::ConfigurationError => error
    prescription&.update!(scan_status: :failed, scan_failure_class: error.class.name)
    raise
  end
end
