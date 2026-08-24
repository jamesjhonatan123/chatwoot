class MediaAssets::ResolveBlobsService
  def initialize(account:, media_asset_ids: [])
    @account = account
    @media_asset_ids = Array(media_asset_ids).compact_blank.map(&:to_i).uniq
  end

  def perform
    return [] if @media_asset_ids.blank?

    assets = @account.media_assets.where(id: @media_asset_ids).includes(file_attachment: :blob)
    assets.filter_map(&:blob)
  end
end
