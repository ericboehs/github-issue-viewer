class AccountController < ApplicationController
  def show
    @user = Current.user

    # Redirect to edit if no GitHub token is configured
    if @user.github_token.blank?
      redirect_to edit_account_path
    end
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(user_params)
      redirect_to account_path, notice: "Account updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy_all_sessions
    @user = Current.user

    # Keep the current session but destroy all others
    current_session_id = Current.session.id
    @user.sessions.where.not(id: current_session_id).destroy_all

    redirect_to account_path, notice: "All other sessions have been logged out."
  end

  private

  def user_params
    params.require(:user).permit(:github_token)
  end
end
