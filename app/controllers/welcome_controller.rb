class WelcomeController < ApplicationController
  allow_unauthenticated_access

  def index
    if Current.user
      # Check for last searched repository in cookie
      if cookies[:last_repo].present?
        last_repo = JSON.parse(cookies[:last_repo]) rescue {}
        if last_repo["owner"].present? && last_repo["repository"].present?
          redirect_to issues_path(owner: last_repo["owner"], repository: last_repo["repository"])
          return
        end
      end
      redirect_to issues_path
    end
  end
end
