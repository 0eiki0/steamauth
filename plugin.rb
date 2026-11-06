# frozen_string_literal: true

# name: discourse-steam-login
# about: Anmeldung und Registrierung mit einem Steam-Konto
# version: 1.0.0
# authors: Marcel Eikmeier
# url: https://github.com/0eiki0/steamauth
# required_version: 3.3.0

enabled_site_setting :steam_login_enabled

module ::SteamAuth
  PLUGIN_NAME = "discourse-steam-login"
end

require_relative "lib/steam_auth/strategy"
require_relative "lib/steam_auth/authenticator"

register_svg_icon "fab-steam"

auth_provider authenticator: SteamAuth::Authenticator.new, icon: "fab-steam"
