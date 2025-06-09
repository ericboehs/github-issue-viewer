class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      # Store GitHub token in session if provided
      session[:github_token] = params[:user][:github_token] if params[:user][:github_token].present?
      redirect_to issues_path, notice: "Welcome, #{@user.email_address}! You have signed up successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
