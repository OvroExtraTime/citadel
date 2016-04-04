class UsersController < ApplicationController
  include UsersPermissions
  include Searchable

  before_action except: [:index, :new, :create, :logout] { @user = User.find(params[:id]) }

  before_action :require_login, only: [:logout]
  before_action :require_user_permission, only: [:edit, :update]

  def index
    @users = User.search_all(params[:q]).paginate(page: params[:page])
  end

  def new
    steam_data = session['devise.steam_data']
    @user = User.new(name: params[:name], steam_id: steam_data['uid'])
  end

  def create
    steam_data = session['devise.steam_data']
    @user = User.new(user_params.update(steam_id: steam_data['uid']))

    if @user.save
      sign_in @user
      render :show
    else
      render :new
    end
  end

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to(user_path(@user))
    else
      render :edit
    end
  end

  def logout
    sign_out current_user
    redirect_to(:back)
  end

  private

  def user_params
    params.require(:user).permit(:name, :avatar, :description)
  end

  def require_user_permission
    redirect_to user_path(@user) unless user_can_edit_user?
  end
end
