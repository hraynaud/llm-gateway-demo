module Api
  module V1
    class AiOnboardingChatController < ApplicationController
      include ActionController::Live

      def create
        message = msg_params[:message]
        history = msg_params[:history] || []
        ai_assistant = AiService.onboarding_assistant
        response = ai_assistant.chat(message, history)

        render json: { text: response }
      end

      private

      def msg_params
        params.permit(:message, :mode, history: %i[role content])
      end
    end
  end
end
