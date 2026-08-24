json.payload do
  json.array! @media_assets do |media_asset|
    json.partial! 'api/v1/models/media_asset', formats: [:json], resource: media_asset
  end
end
