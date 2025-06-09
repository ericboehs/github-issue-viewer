class RemoveGithubTokenFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :github_token, :string
  end
end
