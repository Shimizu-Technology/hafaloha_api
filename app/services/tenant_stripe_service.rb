# app/services/tenant_stripe_service.rb
class TenantStripeService < TenantScopedService
  attr_accessor :current_user

  # Create a payment intent for Stripe
  def create_payment_intent(amount, currency = "USD")
    # Get payment settings from restaurant
    payment_settings = @restaurant.admin_settings&.dig("payment_gateway") || {}

    # Check if test mode is enabled
    test_mode = payment_settings["test_mode"]

    if test_mode
      # Generate a dummy client secret in test mode
      client_secret = "pi_test_#{SecureRandom.hex(16)}_secret_#{SecureRandom.hex(16)}"
      return { success: true, client_secret: client_secret }
    end

    # Check if Stripe is configured
    unless payment_settings["secret_key"].present?
      return { 
        success: false, 
        errors: ["Stripe is not properly configured for this restaurant"], 
        status: :service_unavailable 
      }
    end

    # Check for zero or small amounts - Stripe has minimum amount requirements
    # For USD, the minimum is 50 cents
    if amount.to_f <= 0
      # For free items, return a special flag instead of a client secret
      return { 
        success: true, 
        free_order: true,
        order_id: "free_#{SecureRandom.hex(8)}"
      }
    end
    
    # Handle small amounts (less than minimum required by Stripe)
    # Stripe minimum amounts vary by currency:
    # - USD: 50 cents
    # - EUR: 50 cents
    # - GBP: 30 pence
    # - etc.
    min_amounts = {
      "USD" => 0.5,  # 50 cents
      "EUR" => 0.5,  # 50 cents
      "GBP" => 0.3,  # 30 pence
      "CAD" => 0.5,  # 50 cents
      "AUD" => 0.5,  # 50 cents
      "JPY" => 50,   # 50 yen
    }
    
    # Default to 50 cents USD equivalent if currency not in the list
    min_amount = min_amounts[currency.upcase] || 0.5
    
    # Only treat as a small order if amount is LESS than the minimum (not equal)
    # This ensures we only bypass Stripe for amounts that Stripe can't handle
    if amount.to_f < min_amount
      Rails.logger.info("Small amount detected: $#{amount}. Using minimum amount for Stripe: $#{min_amount}")
      # For small amounts, treat as a special small order
      return { 
        success: true, 
        small_order: true,
        order_id: "small_#{SecureRandom.hex(8)}"
      }
    end

    # Stripe deals with amounts in cents
    amount_in_cents = (amount.to_f * 100).to_i

    begin
      # Set the API key for this specific restaurant
      # This is crucial for multi-tenant applications where each restaurant has its own Stripe account
      secret_key = payment_settings["secret_key"]
      
      # Create a payment intent with Stripe using the restaurant's API key
      payment_intent = Stripe::PaymentIntent.create({
        amount: amount_in_cents,
        currency: currency.downcase,
        metadata: {
          restaurant_id: @restaurant.id,
          test_mode: test_mode
        },
        automatic_payment_methods: {
          enabled: true
        }
      }, {
        api_key: secret_key # Pass the restaurant-specific API key
      })

      { success: true, client_secret: payment_intent.client_secret }
    rescue Stripe::StripeError => e
      # Log detailed Stripe error information
      Rails.logger.error("Stripe Error for restaurant #{@restaurant.id} (#{@restaurant.name}): #{e.message}")
      Rails.logger.error("Stripe Error Type: #{e.class.name}")
      Rails.logger.error("Stripe Error HTTP Status: #{e.http_status}")
      Rails.logger.error("Stripe Error Code: #{e.code}")
      Rails.logger.error("Stripe Error JSON Body: #{e.json_body}")
      
      { success: false, errors: [e.message], status: :unprocessable_entity }
    rescue => e
      # Log general error information
      Rails.logger.error("Unexpected error for restaurant #{@restaurant.id} (#{@restaurant.name}) when creating payment intent: #{e.message}")
      Rails.logger.error("Error Backtrace: #{e.backtrace.join("\n")}")
      
      { success: false, errors: ["An unexpected error occurred: #{e.message}"], status: :internal_server_error }
    end
  end

  # Process a webhook event from Stripe
  def process_webhook(payload, signature)
    # Get payment settings from restaurant
    payment_settings = @restaurant.admin_settings&.dig("payment_gateway") || {}
    
    # Get webhook secret from settings
    webhook_secret = payment_settings["webhook_secret"]
    
    unless webhook_secret.present?
      return { 
        success: false, 
        errors: ["Webhook secret is not configured for this restaurant"], 
        status: :service_unavailable 
      }
    end
    
    begin
      # Get the secret key for this restaurant
      secret_key = payment_settings["secret_key"]
      
      # Verify the webhook signature using the restaurant's API key
      event = Stripe::Webhook.construct_event(
        payload, signature, webhook_secret,
        { api_key: secret_key } # Pass the restaurant-specific API key
      )
      
      # Process the event based on its type
      case event.type
      when 'payment_intent.succeeded'
        payment_intent = event.data.object
        process_successful_payment(payment_intent)
      when 'payment_intent.payment_failed'
        payment_intent = event.data.object
        process_failed_payment(payment_intent)
      else
        # Log other event types but don't take specific action
        Rails.logger.info("Unhandled Stripe event type: #{event.type}")
      end
      
      { success: true }
    rescue JSON::ParserError => e
      { success: false, errors: ["Invalid payload: #{e.message}"], status: :bad_request }
    rescue Stripe::SignatureVerificationError => e
      { success: false, errors: ["Invalid signature: #{e.message}"], status: :bad_request }
    rescue => e
      { success: false, errors: ["An unexpected error occurred: #{e.message}"], status: :internal_server_error }
    end
  end
  
  private
  
  # Process a successful payment
  def process_successful_payment(payment_intent)
    # Find the order associated with this payment intent
    order = find_order_by_payment_intent(payment_intent.id)
    return unless order
    
    # Update the order status
    order.update(
      status: "paid",
      payment_status: "paid",
      payment_details: order.payment_details.merge({
        stripe_payment_intent_id: payment_intent.id,
        payment_method: "stripe",
        payment_status: "succeeded"
      })
    )
    
    # Create a payment record
    OrderPayment.create(
      order: order,
      amount: payment_intent.amount / 100.0, # Convert from cents
      payment_method: "stripe",
      status: "paid",
      transaction_id: payment_intent.id,
      payment_details: {
        stripe_payment_intent_id: payment_intent.id,
        payment_method_details: payment_intent.payment_method_details
      }
    )
  end
  
  # Process a failed payment
  def process_failed_payment(payment_intent)
    # Find the order associated with this payment intent
    order = find_order_by_payment_intent(payment_intent.id)
    return unless order
    
    # Update the order status
    order.update(
      payment_status: "failed",
      payment_details: order.payment_details.merge({
        stripe_payment_intent_id: payment_intent.id,
        payment_method: "stripe",
        payment_status: "failed",
        error_message: payment_intent.last_payment_error&.message
      })
    )
  end
  
  # Find an order by payment intent ID
  def find_order_by_payment_intent(payment_intent_id)
    scope_query(Order).find_by("payment_details->>'stripe_payment_intent_id' = ?", payment_intent_id)
  end
end
