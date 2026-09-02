require "rails_helper"
require Rails.root.join("config/oidc_signing_key").to_s

# The signing key has to be configurable from places that cannot hold a
# multi-line value — a Docker `--env-file`, a systemd `EnvironmentFile`, a
# Heroku-style config store. Pasting a PEM into one of those silently truncates
# it, so these specs pin down the alternatives.
RSpec.describe OidcSigningKey do
  let(:pem) { OpenSSL::PKey::RSA.new(2048).to_pem }

  def with_env(vars)
    original = vars.transform_values { |_| nil }.merge(ENV.slice(*vars.keys))
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  describe "from a file path" do
    it "reads the key from disk" do
      file = Tempfile.new(["signing", ".pem"])
      file.write(pem)
      file.close

      with_env(described_class::PATH_VAR => file.path) do
        expect(described_class.resolve).to eq(pem)
      end
    ensure
      file&.unlink
    end

    it "fails loudly when the path is wrong" do
      with_env(described_class::PATH_VAR => "/nowhere/missing.pem") do
        expect { described_class.resolve }.to raise_error(/cannot be read/)
      end
    end
  end

  describe "from base64" do
    it "decodes a one-line value" do
      with_env(described_class::BASE64_VAR => Base64.strict_encode64(pem)) do
        expect(described_class.resolve).to eq(pem)
      end
    end

    it "tolerates surrounding whitespace from copy-paste" do
      with_env(described_class::BASE64_VAR => "  #{Base64.strict_encode64(pem)}\n") do
        expect(described_class.resolve).to eq(pem)
      end
    end

    # Without this the garbage would travel on and fail deep inside OpenSSL,
    # where the message says nothing about the variable that caused it.
    it "rejects a value that is not base64" do
      with_env(described_class::BASE64_VAR => "this is not base64!!") do
        expect { described_class.resolve }.to raise_error(/not valid base64/)
      end
    end
  end

  describe "from the raw variable" do
    it "uses the PEM as given" do
      with_env(described_class::RAW_VAR => pem) do
        expect(described_class.resolve).to eq(pem)
      end
    end
  end

  describe "precedence" do
    it "prefers the file over base64 and raw" do
      file = Tempfile.new(["signing", ".pem"])
      file.write(pem)
      file.close

      other = OpenSSL::PKey::RSA.new(2048).to_pem

      with_env(
        described_class::PATH_VAR => file.path,
        described_class::BASE64_VAR => Base64.strict_encode64(other),
        described_class::RAW_VAR => other,
      ) do
        expect(described_class.resolve).to eq(pem)
      end
    ensure
      file&.unlink
    end
  end

  describe "with nothing configured" do
    it "generates a usable key rather than taking the site down" do
      with_env(
        described_class::PATH_VAR => nil,
        described_class::BASE64_VAR => nil,
        described_class::RAW_VAR => nil,
      ) do
        expect(OpenSSL::PKey::RSA.new(described_class.resolve)).to be_private
      end
    end

    it "warns in production, because signatures then break across restarts" do
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(Rails.logger).to receive(:warn)

      with_env(
        described_class::PATH_VAR => nil,
        described_class::BASE64_VAR => nil,
        described_class::RAW_VAR => nil,
      ) do
        described_class.resolve
      end

      expect(Rails.logger).to have_received(:warn).with(/ephemeral key/)
    end
  end
end
