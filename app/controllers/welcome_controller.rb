class WelcomeController < ApplicationController
  allow_unauthenticated_access

  def index
    if Current.user
      redirect_to issues_path
    end
  end
end
