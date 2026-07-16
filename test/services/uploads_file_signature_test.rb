require "test_helper"

class UploadsFileSignatureTest < ActiveSupport::TestCase
  test "accepts bounded real signatures and rejects mime spoofing" do
    assert Uploads::FileSignature.valid?(StringIO.new("%PDF-1.7 fake test content"), "application/pdf")
    assert Uploads::FileSignature.valid?(StringIO.new("\xFF\xD8\xFFfake".b), "image/jpeg")
    assert_not Uploads::FileSignature.valid?(StringIO.new("not a pdf"), "application/pdf")
    assert_not Uploads::FileSignature.valid?(StringIO.new("%PDF-1.7"), "image/png")
  end
end
