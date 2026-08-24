json.payload do
  json.partial! 'api/v1/models/media_asset', formats: [:json], resource: @media_asset
end
