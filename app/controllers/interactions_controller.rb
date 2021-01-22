class InteractionsController < ActionController::API
  before_action :verify_request

  PING_JSON = { type: 1 }.to_json.freeze

  def create
    json = JSON.parse(request.body.read)

    # discord needs to be able to ping the interaction endpoint
    if json['type'] == 1
      render json: PING_JSON
    else
      # json = JSON.parse(request.body.read)
      user_ids = Array(params.dig(:data, :options)).select do |ha|
                   ha['name'].starts_with? 'user'
                 end.map { |ha| ha['value'] }
      mentions = user_ids.map { |id| mention(id) }.to_sentence

      render json: {
        type: 3,
        data: {
          tts: false,
          content: "Congrats on sending your command, #{mentions}!",
          embeds: [],
          allowed_mentions: []
        }
      }.to_json
    end
  end

  def mention(user_id)
    "<@#{user_id}>"
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
