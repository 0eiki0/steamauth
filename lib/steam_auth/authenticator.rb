# frozen_string_literal: true

module ::SteamAuth
  class Authenticator < ::Auth::ManagedAuthenticator
    def name
      "steam"
    end

    def display_name
      "Steam"
    end

    def provider_url
      "https://steamcommunity.com"
    end

    def enabled?
      SiteSetting.steam_login_enabled
    end

    def register_middleware(omniauth)
      omniauth.provider SteamAuth::Strategy,
                        name: "steam",
                        setup:
                          lambda { |env|
                            strategy = env["omniauth.strategy"]
                            strategy.options[:api_key] = SiteSetting.steam_web_api_key
                            strategy.options[:import_avatar] = SiteSetting.steam_login_import_avatar
                          }
    end

    # Steam liefert keine E-Mail-Adresse – sie wird bei der Registrierung abgefragt
    def match_by_email
      false
    end

    def primary_email_verified?(_auth_token)
      false
    end

    # Anzeige unter "Verknüpfte Konten" im Profil
    def description_for_auth_hash(auth_token)
      return if auth_token&.info.nil?
      auth_token.info["nickname"].presence || auth_token.extra&.dig("steam_id")
    end
  end
end
