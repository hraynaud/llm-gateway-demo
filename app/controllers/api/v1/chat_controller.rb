module Api
  module V1
    class ChatController < ApplicationController
      include ActionController::Live

      def create
        message = msg_params[:message]
        mode = msg_params[:mode]&.to_sym
        history = msg_params[:history] || []
        model_type = msg_params[:model_type]&.to_sym # Optional override

        if mode && %i[project onboarding].include?(mode)
          # Use AI Assistant for project wizard or onboarding
          ai_assistant = AiAssistant.new(mode, model_type)
          response = ai_assistant.chat(message, history)

          render json: { text: response }

        else
          # Use existing chat service for general chat
          response = ChatService.new.chat_non_streaming(message)
          render json: { data: response }
        end
      end

      # New streaming endpoint
      def stream # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        message = msg_params[:message]
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['Connection'] = 'keep-alive'

        sse = SSE.new(response.stream, retry: 300)

        begin
          chat_service = ChatService.new
          chat_service.chat(message).each do |chunk|
            sse.write({ data: chunk })
          end

          # Optional: Send a completion event
          sse.write({ data: '' }, { event: 'complete' })
        rescue IOError => e
          Rails.logger.info("Client disconnected: #{e.message}")
          sse.close
        rescue StandardError => e
          Rails.logger.error("Error in chat stream: #{e.message}")
          sse.write({ error: e.message }, { event: e.message })
          sse.close
        ensure
          sse.close
        end

        head :ok
      end

      private

      def msg_params
        params.permit(:message, :mode, :model_type, history: %i[role content])
      end
    end
  end
end
