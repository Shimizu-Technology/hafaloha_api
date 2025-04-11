class StaffMembersController < ApplicationController
  include TenantIsolation
  
  before_action :authorize_request
  
  # GET /staff_members
  def index
    result = staff_member_service.list_staff_members(params, current_user)
    
    if result[:success]
      render json: {
        staff_members: result[:staff_members],
        total_count: result[:total_count],
        page: result[:page],
        per_page: result[:per_page],
        total_pages: result[:total_pages]
      }, status: :ok
    else
      render json: { error: result[:errors].join(", ") }, status: result[:status] || :internal_server_error
    end
  end
  
  # GET /staff_members/:id
  def show
    result = staff_member_service.get_staff_member(params[:id])
    
    if result[:success]
      render json: result[:staff_member]
    else
      render json: { error: result[:errors].join(", ") }, status: result[:status] || :not_found
    end
  end
  
  # POST /staff_members
  def create
    result = staff_member_service.create_staff_member(staff_member_params, current_user)
    
    if result[:success]
      render json: result[:staff_member], status: :created
    else
      render json: { errors: result[:errors] }, status: result[:status] || :unprocessable_entity
    end
  end
  
  # PATCH/PUT /staff_members/:id
  def update
    result = staff_member_service.update_staff_member(params[:id], staff_member_params, current_user)
    
    if result[:success]
      render json: result[:staff_member]
    else
      render json: { errors: result[:errors] }, status: result[:status] || :unprocessable_entity
    end
  end
  
  # DELETE /staff_members/:id
  def destroy
    result = staff_member_service.delete_staff_member(params[:id], current_user)
    
    if result[:success]
      head :no_content
    else
      render json: { error: result[:errors].join(", ") }, status: result[:status] || :not_found
    end
  end
  
  # GET /staff_members/:id/transactions
  def transactions
    # Add current_user to params for authorization in the service
    params_with_user = params.merge(current_user: current_user)
    result = staff_member_service.get_transactions(params[:id], params_with_user)
    
    if result[:success]
      render json: {
        transactions: result[:transactions],
        total_count: result[:total_count],
        page: result[:page],
        per_page: result[:per_page],
        total_pages: result[:total_pages],
        staff_member: result[:staff_member]
      }, status: :ok
    else
      render json: { error: result[:errors].join(", ") }, status: result[:status] || :not_found
    end
  end
  
  # POST /staff_members/:id/transactions
  def add_transaction
    result = staff_member_service.add_transaction(params[:id], transaction_params, current_user)
    
    if result[:success]
      render json: result[:transaction], status: :created
    else
      render json: { errors: result[:errors] }, status: result[:status] || :unprocessable_entity
    end
  end
  
  private
  
  def staff_member_params
    params.require(:staff_member).permit(:name, :position, :user_id, :active)
  end
  
  def transaction_params
    params.require(:transaction).permit(:amount, :transaction_type, :description, :reference)
  end
  
  def staff_member_service
    @staff_member_service ||= StaffMemberService.new(current_restaurant, analytics)
  end
end
