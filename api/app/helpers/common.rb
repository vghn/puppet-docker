require 'base64'
require 'faraday'
require 'json'
require 'logger'
require 'openssl'
require 'yaml'

# Logging
def log
  Logger.new(STDOUT)
end

# Configuration
def config
  if File.exist?(ENV['DATA_CONFIG'])
    YAML.load_file(ENV['DATA_CONFIG'])
  else
    raise "Configuration file '#{ENV['DATA_CONFIG']}' does not exist"
  end
end

# Download vault
def download_vault
  if ENV['VAULT_S3PATH']
    log.info 'Download vault'
    puts `aws s3 sync --delete --exact-timestamps #{ENV['VAULT_S3PATH']} /etc/puppetlabs/vault/`
    File.write('/var/local/deployed_vault', Time.now.localtime)
    log.info 'Vault downloaded'
  else
    log.warn 'Skip downloading vault because VAULT_S3PATH is not set!'
  end
end

# Download Hiera data
def download_hieradata
  if ENV['HIERA_S3PATH']
    log.info 'Download Hiera data'
    puts `aws s3 sync --delete --exact-timestamps #{ENV['HIERA_S3PATH']} /etc/puppetlabs/hieradata/`
    File.write('/var/local/deployed_hieradata', Time.now.localtime)
    log.info 'Hiera data downloaded'
  else
    log.warn 'Skip downloading hiera data because HIERA_S3PATH is not set!'
  end
end

# Deploy R10K
def deploy_r10k
  log.info 'Deploy R10K'
  `r10k deploy environment --puppetfile`
  File.write('/var/local/deployed_r10k', Time.now.localtime)
  log.info 'R10K deployed'
end

# Deployment
def deploy
  log.info 'Deployment will start in the background'
  Thread.new { download_vault }
  Thread.new { download_hieradata }
  Thread.new { deploy_r10k }
end

def protected!
  unless authorized?
    response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
    return halt 401, 'Not authorized'
  end
end

def authorized?
  @auth ||= Rack::Auth::Basic::Request.new(request.env)
  @auth.provided? && @auth.basic? && @auth.credentials &&
    @auth.credentials == [config['user'], config['pass']]
end

def verify_github_signature(payload_body)
  signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), config['github_secret'], payload_body)
  return halt 500, 'Signatures did not match!' unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
end

def verify_travis_signature(payload)
  signature = request.env['HTTP_SIGNATURE']
  pkey      = OpenSSL::PKey::RSA.new(travis_public_key)

  return halt 500, 'Signatures did not match!' unless pkey.verify(OpenSSL::Digest::SHA1.new, Base64.decode64(signature), payload.to_json)
end

def travis_public_key
  conn = Faraday.new(url: 'https://api.travis-ci.org') do |faraday|
    faraday.adapter Faraday.default_adapter
  end
  response = conn.get '/config'
  JSON.parse(response.body)['config']['notifications']['webhook']['public_key']
end
