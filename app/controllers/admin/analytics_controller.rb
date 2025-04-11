# app/controllers/admin/analytics_controller.rb

module Admin
  class AnalyticsController < ApplicationController
    include TenantIsolation
    
    before_action :authorize_request
    before_action :require_admin!
    before_action :ensure_tenant_context

    # GET /admin/analytics/customer_orders?start=YYYY-MM-DD&end=YYYY-MM-DD
    def customer_orders
      # Use Time.zone.parse to respect any timezone information in the input
      start_date = params[:start].present? ? Time.zone.parse(params[:start]) : (Time.zone.today - 30)
      end_date   = params[:end].present?   ? Time.zone.parse(params[:end])   : Time.zone.today
      
      # Use the AdminAnalyticsService to get tenant-scoped data
      report = analytics_service.customer_orders_report(start_date, end_date)
      
      render json: report
    end

    # GET /admin/analytics/revenue_trend?interval=30min|hour|day|week|month&start=...&end=...
    def revenue_trend
      interval   = params[:interval].presence || "day"
      # Parse with timezone consideration
      start_date = params[:start].present? ? Time.zone.parse(params[:start]) : 30.days.ago
      end_date   = params[:end].present?   ? Time.zone.parse(params[:end])   : Time.zone.now
      
      # Use the AdminAnalyticsService to get tenant-scoped data
      report = analytics_service.revenue_trend_report(interval, start_date, end_date)
      
      render json: report
    end

    # GET /admin/analytics/top_items?limit=5&start=...&end=...
    def top_items
      limit = (params[:limit] || 5).to_i
      # Parse with timezone consideration
      start_date = params[:start].present? ? Time.zone.parse(params[:start]) : 30.days.ago
      end_date   = params[:end].present?   ? Time.zone.parse(params[:end])   : Time.zone.today
      
      # Use the AdminAnalyticsService to get tenant-scoped data
      report = analytics_service.top_items_report(limit, start_date, end_date)
      
      render json: report
    end

    # GET /admin/analytics/income_statement?year=2025
    def income_statement
      year = (params[:year] || Date.today.year).to_i
      
      # Use the AdminAnalyticsService to get tenant-scoped data
      report = analytics_service.income_statement_report(year)
      
      render json: report
    end

    # GET /admin/analytics/user_signups?start=YYYY-MM-DD&end=YYYY-MM-DD
    def user_signups
      # Parse with timezone consideration
      start_date = params[:start].present? ? Time.zone.parse(params[:start]) : (Time.zone.today - 30)
      end_date   = params[:end].present?   ? Time.zone.parse(params[:end])   : Time.zone.today
      
      # Use the AdminAnalyticsService to get tenant-scoped data
      report = analytics_service.user_signups_report(start_date, end_date)
      
      render json: report
    end

    # GET /admin/analytics/user_activity_heatmap?start=YYYY-MM-DD&end=YYYY-MM-DD
    def user_activity_heatmap
      # Parse with timezone consideration
      start_date = params[:start].present? ? Time.zone.parse(params[:start]) : (Time.zone.today - 30)
      end_date   = params[:end].present?   ? Time.zone.parse(params[:end])   : Time.zone.today
      
      # Use the AdminAnalyticsService to get tenant-scoped data
      report = analytics_service.user_activity_heatmap_report(start_date, end_date)
      
      render json: report
    end

    private
    
    # Ensure tenant context is set for all analytics requests
    def ensure_tenant_context
      unless @current_restaurant
        render json: { error: "Restaurant context required" }, status: :unprocessable_entity
      end
    end
    
    # Get the analytics service instance with proper tenant scoping
    def analytics_service
      @analytics_service ||= AdminAnalyticsService.new(@current_restaurant)
    end

    def require_admin!
      unless current_user && current_user.role.in?(%w[admin super_admin])
        render json: { error: "Forbidden" }, status: :forbidden
      end
    end
  end
end
