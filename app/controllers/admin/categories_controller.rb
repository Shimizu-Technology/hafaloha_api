# app/controllers/admin/categories_controller.rb

module Admin
  class CategoriesController < ApplicationController
    before_action :authorize_request
    before_action :check_admin!

    # GET /admin/categories
    def index
      # Could also sort by :position, :name, etc.
      categories = Category.order(:name)
      render json: categories
    end

    # POST /admin/categories
    def create
      category = Category.new(category_params)
      if category.save
        render json: category, status: :created
      else
        render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/categories/:id
    def update
      category = Category.find(params[:id])
      if category.update(category_params)
        render json: category
      else
        render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /admin/categories/:id
    def destroy
      category = Category.find(params[:id])
      category.destroy
      head :no_content
    end

    private

    def category_params
      params.require(:category).permit(:name, :position)
    end

    def check_admin!
      # if current_user role is admin or super_admin
      render json: { error: "Forbidden" }, status: :forbidden unless current_user&.role.in?(%w[admin super_admin])
    end
  end
end
