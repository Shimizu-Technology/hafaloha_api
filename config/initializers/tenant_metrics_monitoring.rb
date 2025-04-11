# config/initializers/tenant_metrics_monitoring.rb
#
# This initializer sets up Prometheus metrics for tenant monitoring and analytics.
# It defines various counters, histograms, and gauges to track tenant-specific
# metrics for performance monitoring and business analytics.
#

require 'prometheus/client'

# Register the Prometheus metrics
prometheus = Prometheus::Client.registry

# Request metrics by tenant
tenant_request_counter = prometheus.counter(
  :tenant_request_total,
  docstring: 'Total number of HTTP requests by tenant',
  labels: [:restaurant_id, :controller, :action, :method, :status]
)

tenant_request_duration = prometheus.histogram(
  :tenant_request_duration_seconds,
  docstring: 'HTTP request duration in seconds by tenant',
  labels: [:restaurant_id, :controller, :action],
  buckets: [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
)

# Error metrics by tenant
tenant_error_counter = prometheus.counter(
  :tenant_error_total,
  docstring: 'Total number of errors by tenant',
  labels: [:restaurant_id, :error_type, :status]
)

# Cross-tenant access attempts
tenant_cross_access_counter = prometheus.counter(
  :tenant_cross_access_attempt_total,
  docstring: 'Total number of cross-tenant access attempts',
  labels: [:source_restaurant_id, :target_restaurant_id, :user_id, :controller, :action]
)

# Resource usage by tenant
tenant_resource_usage = prometheus.gauge(
  :tenant_resource_usage_count,
  docstring: 'Count of resources used by tenant',
  labels: [:restaurant_id, :resource]
)

# Daily active users by tenant
tenant_dau_gauge = prometheus.gauge(
  :tenant_daily_active_users,
  docstring: 'Daily active users by tenant',
  labels: [:restaurant_id]
)

# Monthly active users by tenant
tenant_mau_gauge = prometheus.gauge(
  :tenant_monthly_active_users,
  docstring: 'Monthly active users by tenant',
  labels: [:restaurant_id]
)

# Order metrics by tenant
tenant_order_counter = prometheus.counter(
  :tenant_order_total,
  docstring: 'Total number of orders by tenant',
  labels: [:restaurant_id, :payment_method, :status]
)

tenant_order_value_counter = prometheus.counter(
  :tenant_order_value_total,
  docstring: 'Total value of orders by tenant',
  labels: [:restaurant_id, :payment_method]
)

# Background job metrics by tenant
tenant_job_counter = prometheus.counter(
  :tenant_job_total,
  docstring: 'Total number of background jobs by tenant',
  labels: [:restaurant_id, :job_class, :status]
)

tenant_job_duration = prometheus.histogram(
  :tenant_job_duration_seconds,
  docstring: 'Background job duration in seconds by tenant',
  labels: [:restaurant_id, :job_class],
  buckets: [0.1, 0.5, 1, 2.5, 5, 10, 30, 60, 120, 300]
)

# Update resource usage metrics periodically
Thread.new do
  # Only run in production or when explicitly enabled
  next unless Rails.env.production? || ENV['ENABLE_METRICS'] == 'true'
  
  loop do
    begin
      # Sleep for a while to avoid excessive DB queries
      sleep(ENV.fetch('METRICS_UPDATE_INTERVAL', 300).to_i)
      
      # Update resource usage metrics for each restaurant
      Restaurant.find_each do |restaurant|
        # Count orders
        order_count = Order.where(restaurant_id: restaurant.id).count
        tenant_resource_usage.set(order_count, labels: { restaurant_id: restaurant.id, resource: 'orders' })
        
        # Count users
        user_count = User.where(restaurant_id: restaurant.id).count
        tenant_resource_usage.set(user_count, labels: { restaurant_id: restaurant.id, resource: 'users' })
        
        # Count menu items
        menu_item_count = MenuItem.where(restaurant_id: restaurant.id).count
        tenant_resource_usage.set(menu_item_count, labels: { restaurant_id: restaurant.id, resource: 'menu_items' })
        
        # Count reservations
        reservation_count = Reservation.where(restaurant_id: restaurant.id).count
        tenant_resource_usage.set(reservation_count, labels: { restaurant_id: restaurant.id, resource: 'reservations' })
        
        # Update DAU/MAU metrics
        dau = TenantMetricsService.daily_active_users(restaurant)
        mau = TenantMetricsService.monthly_active_users(restaurant)
        
        tenant_dau_gauge.set(dau, labels: { restaurant_id: restaurant.id })
        tenant_mau_gauge.set(mau, labels: { restaurant_id: restaurant.id })
      end
    rescue => e
      # Log error but don't crash the thread
      Rails.logger.error("Error updating tenant metrics: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end
end

# Instrument ActionController for request metrics
ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  payload = event.payload
  
  # Skip if we don't have a restaurant_id
  next unless payload[:restaurant_id].present?
  
  # Extract request details
  controller = payload[:controller]
  action = payload[:action]
  method = payload[:method]
  status = payload[:status]
  duration = event.duration / 1000.0 # Convert from ms to seconds
  restaurant_id = payload[:restaurant_id]
  
  # Increment request counter
  tenant_request_counter.increment(
    labels: {
      restaurant_id: restaurant_id,
      controller: controller,
      action: action,
      method: method,
      status: status
    }
  )
  
  # Record request duration
  tenant_request_duration.observe(
    duration,
    labels: {
      restaurant_id: restaurant_id,
      controller: controller,
      action: action
    }
  )
  
  # Track errors (status >= 400)
  if status.to_i >= 400
    tenant_error_counter.increment(
      labels: {
        restaurant_id: restaurant_id,
        error_type: "http_#{status}",
        status: status
      }
    )
  end
end

# Instrument ActiveJob for background job metrics
ActiveSupport::Notifications.subscribe('perform.active_job') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  payload = event.payload
  
  # Extract job details
  job = payload[:job]
  job_class = job.class.name
  
  # Skip if we don't have a restaurant_id
  restaurant_id = job.arguments.first.try(:restaurant_id) if job.arguments.first.is_a?(ActiveRecord::Base)
  restaurant_id ||= job.arguments.first[:restaurant_id] if job.arguments.first.is_a?(Hash) && job.arguments.first[:restaurant_id]
  next unless restaurant_id.present?
  
  # Calculate duration
  duration = event.duration / 1000.0 # Convert from ms to seconds
  
  # Determine job status
  status = payload[:exception] ? 'failed' : 'completed'
  
  # Increment job counter
  tenant_job_counter.increment(
    labels: {
      restaurant_id: restaurant_id,
      job_class: job_class,
      status: status
    }
  )
  
  # Record job duration
  tenant_job_duration.observe(
    duration,
    labels: {
      restaurant_id: restaurant_id,
      job_class: job_class
    }
  )
end

# Instrument cross-tenant access attempts
ActiveSupport::Notifications.subscribe('tenant.cross_access_attempt') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  payload = event.payload
  
  # Increment cross-tenant access counter
  tenant_cross_access_counter.increment(
    labels: {
      source_restaurant_id: payload[:source_restaurant_id],
      target_restaurant_id: payload[:target_restaurant_id],
      user_id: payload[:user_id],
      controller: payload[:controller],
      action: payload[:action]
    }
  )
end

# Instrument order creation for order metrics
ActiveSupport::Notifications.subscribe('order.created') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  payload = event.payload
  
  order = payload[:order]
  restaurant_id = order.restaurant_id
  payment_method = order.payment_method || 'unknown'
  status = order.status
  
  # Increment order counter
  tenant_order_counter.increment(
    labels: {
      restaurant_id: restaurant_id,
      payment_method: payment_method,
      status: status
    }
  )
  
  # Increment order value counter
  tenant_order_value_counter.increment(
    by: order.total_amount.to_f,
    labels: {
      restaurant_id: restaurant_id,
      payment_method: payment_method
    }
  )
end
