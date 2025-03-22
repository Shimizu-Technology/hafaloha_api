module Admin
  class SystemController < ApplicationController
    before_action :authorize_admin, except: [:test_pushover, :validate_pushover_key, :test_sms, :generate_web_push_keys]
    
    def test_sms
      to = params[:phone]
      body = "This is a test message from #{Rails.application.class.module_parent_name} at #{Time.current.strftime('%H:%M:%S')}"
      
      result = ClicksendClient.send_text_message(
        to: to,
        body: body,
        from: params[:from] || "Test"
      )
      
      if result
        render json: { status: "success", message: "Test SMS queued for delivery" }
      else
        render json: { status: "error", message: "Failed to send test SMS" }, status: :internal_server_error
      end
    end
    
    def test_pushover
      user_key = params[:user_key]
      
      if user_key.blank?
        return render json: { error: "User key is required" }, status: :bad_request
      end
      
      message = params[:message] || "This is a test notification from #{Rails.application.class.module_parent_name} at #{Time.current.strftime('%H:%M:%S')}"
      title = params[:title] || "Test Notification"
      
      # Send test notification
      success = PushoverClient.send_notification(
        user_key: user_key,
        message: message,
        title: title,
        app_token: params[:app_token],
        priority: params[:priority]&.to_i || 0,
        sound: params[:sound]
      )
      
      if success
        render json: { status: "success", message: "Test notification sent successfully" }
      else
        render json: { status: "error", message: "Failed to send test notification" }, status: :internal_server_error
      end
    end
    
    def validate_pushover_key
      user_key = params[:user_key]
      
      if user_key.blank?
        return render json: { error: "User key is required" }, status: :bad_request
      end
      
      # Validate the user key
      valid = PushoverClient.validate_user_key(user_key, params[:app_token])
      
      if valid
        render json: { status: "success", message: "User key is valid", valid: true }
      else
        render json: { status: "error", message: "User key is invalid or could not be validated", valid: false }
      end
    end
    
    def generate_web_push_keys
      # Get restaurant ID from params
      restaurant_id = params[:restaurant_id]
      
      # Find the restaurant
      restaurant = Restaurant.find_by(id: restaurant_id)
      
      # Ensure we have a restaurant
      unless restaurant
        return render json: { error: "Restaurant not found" }, status: :not_found
      end
      
      # Generate new VAPID keys
      begin
        # Make sure the webpush gem is available
        unless defined?(Webpush)
          return render json: { 
            status: "error", 
            message: "Webpush gem is not available" 
          }, status: :internal_server_error
        end
        
        # Generate new VAPID keys
        vapid_keys = restaurant.generate_web_push_vapid_keys!
        
        render json: { 
          status: "success", 
          message: "VAPID keys generated successfully",
          public_key: vapid_keys[:public_key],
          private_key: vapid_keys[:private_key]
        }
      rescue => e
        render json: { 
          status: "error", 
          message: "Failed to generate VAPID keys: #{e.message}" 
        }, status: :internal_server_error
      end
    end
    
    private
    
    def authorize_admin
      unless current_user&.role.in?(%w[admin super_admin])
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
    
    # Mark these endpoints as public (no restaurant context required)
    def public_endpoint?
      ["test_pushover", "validate_pushover_key", "test_sms", "generate_web_push_keys"].include?(action_name)
    end
  end
end
