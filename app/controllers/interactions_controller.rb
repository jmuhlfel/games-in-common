class InteractionsController < ActionController::API
  before_action :verify_request

  PING_JSON = { type: 1 }.to_json.freeze

  def create
    json = JSON.parse(request.body.read)

    # discord needs to be able to ping the interaction endpoint
    if json['type'] == 1
      render json: PING_JSON
    else
      interaction = Interaction.new(params)

      if interaction.valid?
        ResponseJob.perform_later(
          user_ids: interaction.user_ids,
          interaction_token: interaction.token
        )
        render json: interaction.response.to_json
      else
        head :bad_request
      end
    end
  end

  private

  def verify_request
    signature = request.headers['X-Signature-Ed25519']
    timestamp = request.headers['X-Signature-Timestamp']

    return head(:unauthorized) unless signature && timestamp

    verify_key = Ed25519::VerifyKey.new([ENV['DISCORD_APP_PUBLIC_KEY']].pack('H*'))

    verify_key.verify([signature].pack('H*'), timestamp + request.body.read.to_s)
  rescue Ed25519::VerifyError
    head :unauthorized
  end
end