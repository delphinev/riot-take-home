require "rails_helper"
require "open3"

RSpec.describe "HMAC_SECRET" do
  # Boots the app in a separate process, since the check runs once, at boot.
  def boot(rails_env, hmac_secret)
    env = { "RAILS_ENV" => rails_env, "HMAC_SECRET" => hmac_secret, "SECRET_KEY_BASE" => "dummy" }
    output, status = Open3.capture2e(env, "bin/rails", "runner", "print Rails.configuration.x.hmac_secret")
    [ output, status.success? ]
  end

  it "falls back to the fixed key in development when it is missing", :aggregate_failures do
    output, booted = boot("development", nil)

    expect(booted).to be(true)
    expect(output).to end_with("insecure-hmac-secret-for-development-and-test")
  end

  it "refuses to boot in production when it is missing", :aggregate_failures do
    output, booted = boot("production", nil)

    expect(booted).to be(false)
    expect(output).to include("HMAC_SECRET must be set")
  end

  it "refuses to boot when it is shorter than 32 bytes", :aggregate_failures do
    output, booted = boot("production", "a" * 31)

    expect(booted).to be(false)
    expect(output).to include("HMAC_SECRET must be at least 32 bytes long")
  end

  it "boots in production with a 32-byte key", :aggregate_failures do
    output, booted = boot("production", "a" * 32)

    expect(booted).to be(true)
    expect(output).to end_with("a" * 32)
  end
end
