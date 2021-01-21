class InteractionsController < ActionController::API

  before_action :verify_request

  PING_JSON = { type: 1 }.to_json.freeze

  def create
    json = JSON.parse(request.body.read)

    # discord needs to be able to ping the interaction endpoint
    puts 'asldkfjsadlfjasdlkfjaslkdjf'

    puts json
    if json["type"] == 1
      render json: PING_JSON
      return
    end
  end

  private

  def verify_request
    puts '-------------------------- verify_request --------------------------'
    verify_key = Ed25519::VerifyKey.new([ENV["DISCORD_APP_PUBLIC_KEY"]].pack('H*'))

    signature = request.headers["X-Signature-Ed25519"]
    timestamp = request.headers["X-Signature-Timestamp"]
    puts request.body.read
    puts signature
    puts timestamp
    return head(:unauthorized) unless signature && timestamp

    verify_key.verify([signature].pack('H*'), timestamp + request.body.read.to_s)
  rescue Ed25519::VerifyError
    head :unauthorized
  end

end
