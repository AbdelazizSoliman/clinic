class BranchesController < ApplicationController
  before_action :authenticate_user!

  def update
    branch = current_user.accessible_branches.find_by(id: params[:id])
    return head :not_found unless branch
    session[:branch_id] = branch.id
    Current.branch = branch
    redirect_back fallback_location: staff_root_path, notice: "تم اختيار #{branch.display_name}"
  end
end
