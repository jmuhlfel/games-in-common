class Interaction
  include ActiveModel::Validations

  attr_reader :params

  validates :params, presence: true
  validates :user_ids, length: { minimum: 2 }

  def initialize(params)
    @params = params
  end

  def user_ids
    @user_ids ||= Array(@params.dig(:data, :options)).select do |ha|
      ha['name'].starts_with? 'user'
    end.map { |ha| ha['value'] }
  end

  def mention_phrase
    user_ids.map { |id| mention(id) }.to_sentence
  end

  def mention(user_id)
    "<@#{user_id}>"
  end

  def response
    {
      type: 3, # hide the command, but show our response message
      data: {
        tts: false,
        content: "Checking on authorization for #{mention_phrase}...",
        embeds: [],
        allowed_mentions: []
      }
    }
  end
end
