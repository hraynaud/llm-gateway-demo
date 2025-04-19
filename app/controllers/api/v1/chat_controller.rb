module Api
  module V1
    class ChatController < ApplicationController
      include ActionController::Live

      def create
        message = msg_params[:message]
        response = ChatService.new.chat_non_streaming(message)

        render json: { data: response }
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
        params.permit(:message)
      end
    end
  end
end
