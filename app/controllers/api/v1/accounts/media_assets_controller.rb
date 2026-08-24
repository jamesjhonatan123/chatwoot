class Api::V1::Accounts::MediaAssetsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :media_asset, only: [:show, :update, :destroy]

  def index
    @media_assets = Current.account.media_assets
                           .includes(file_attachment: :blob)
                           .order(created_at: :desc)
    @media_assets = @media_assets.where(file_type: params[:file_type]) if params[:file_type].present?
    @media_assets = @media_assets.search(params[:q]) if params[:q].present?
  end

  def show; end

  def create
    @media_asset = Current.account.media_assets.new(media_asset_params.except(:file))
    @media_asset.user = Current.user
    @media_asset.file.attach(params[:file] || params.dig(:media_asset, :file))
    @media_asset.save!
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.message)
  end

  def update
    @media_asset.update!(media_asset_params.except(:file))
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.message)
  end

  def destroy
    authorize(@media_asset)
    @media_asset.destroy!
    head :ok
  end

  private

  def media_asset
    @media_asset ||= Current.account.media_assets.find(params[:id])
  end

  def media_asset_params
    params.permit(:title, :description, :file, media_asset: [:title, :description, :file]).tap do |whitelisted|
      nested = whitelisted.delete(:media_asset) || {}
      whitelisted[:title] ||= nested[:title]
      whitelisted[:description] ||= nested[:description]
      whitelisted[:file] ||= nested[:file]
    end
  end
end
