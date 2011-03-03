require 'oauth'

class ClientApplication < Sequel::Model

  plugin :validation_helpers

  one_to_many :tokens, :class_name => :OauthToken
  one_to_many :access_tokens
  one_to_many :oauth2_verifiers
  one_to_many :oauth_tokens

  def validate
    validates_format /\Ahttp(s?):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/i, :url
    validates_format /\Ahttp(s?):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/i, :support_url,  :allow_blank => true
    validates_format /\Ahttp(s?):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/i, :callback_url, :allow_blank => true
  end

  attr_accessor :token_callback_url

  def self.find_token(token_key)
    return nil if token_key.nil?
    token = ::RequestToken.first(:token => token_key) || ::AccessToken.first(:token => token_key)
    if token && token.authorized?
      token
    else
      nil
    end
  end

  def self.find_by_key(key)
    first(:key => key)
  end

  def user
    User[user_id]
  end

  def user=(value)
    set(:user_id => value.id)
  end

  def self.verify_request(request, options = {}, &block)
    begin
      signature = OAuth::Signature.build(request, options, &block)
      return false unless OauthNonce.remember(signature.request.nonce, signature.request.timestamp)
      value = signature.verify
      value
    rescue OAuth::Signature::UnknownSignatureMethod => e
      false
    end
  end

  def oauth_server
    @oauth_server ||= OAuth::Server.new("http://your.site")
  end

  def credentials
    @oauth_client ||= OAuth::Consumer.new(key, secret)
  end

  # If your application requires passing in extra parameters handle it here
  def create_request_token(params={})
    RequestToken.create :client_application => self, :callback_url=>self.token_callback_url
  end

  def before_create
    self.key = OAuth::Helper.generate_key(40)[0,40]
    self.secret = OAuth::Helper.generate_key(40)[0,40]
    self.created_at = Time.now
  end

  def before_save
    self.updated_at = Time.now
  end

end
