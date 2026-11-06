# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module ::SteamAuth
  # OmniAuth-Strategie für die Steam-Anmeldung.
  #
  # Steam nutzt OpenID 2.0 (nicht OAuth2/OpenID Connect). Der Ablauf:
  #   1. Weiterleitung zu Steam (checkid_setup)
  #   2. Steam leitet mit einer signierten Antwort zurück
  #   3. Die Antwort wird direkt bei Steam geprüft (check_authentication)
  #   4. Aus der bestätigten Claimed-ID wird die SteamID64 gelesen
  #   5. Optional: Name und Profilbild über die Steam Web API
  class Strategy
    include OmniAuth::Strategy

    STEAM_OPENID_ENDPOINT = "https://steamcommunity.com/openid/login"
    OPENID_NS = "http://specs.openid.net/auth/2.0"
    IDENTIFIER_SELECT = "http://specs.openid.net/auth/2.0/identifier_select"
    CLAIMED_ID_PATTERN = %r{\Ahttps://steamcommunity\.com/openid/id/(\d{17})\z}
    PLAYER_SUMMARIES_URL = "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/"
    MAX_NONCE_AGE = 5 * 60 # Sekunden
    HTTP_TIMEOUT = 10 # Sekunden

    option :name, "steam"
    option :api_key, nil
    option :import_avatar, true

    def request_phase
      params = {
        "openid.ns" => OPENID_NS,
        "openid.mode" => "checkid_setup",
        "openid.return_to" => callback_url,
        "openid.realm" => full_host,
        "openid.identity" => IDENTIFIER_SELECT,
        "openid.claimed_id" => IDENTIFIER_SELECT,
      }
      redirect "#{STEAM_OPENID_ENDPOINT}?#{URI.encode_www_form(params)}"
    end

    def callback_phase
      openid = openid_params

      return fail!(:invalid_response) if openid["openid.mode"] != "id_res"
      return fail!(:invalid_response) if openid["openid.op_endpoint"] != STEAM_OPENID_ENDPOINT
      return fail!(:invalid_response) if openid["openid.return_to"].to_s.split("?").first != callback_url

      claimed_id = openid["openid.claimed_id"].to_s
      match = CLAIMED_ID_PATTERN.match(claimed_id)
      return fail!(:invalid_response) if match.nil? || openid["openid.identity"] != claimed_id
      return fail!(:invalid_response) unless fresh_nonce?(openid["openid.response_nonce"])
      return fail!(:unauthorized) unless verified_by_steam?(openid)

      @steam_id = match[1]
      super
    rescue StandardError => e
      fail!(:request_error, e)
    end

    uid { @steam_id }

    info do
      data = {
        name: player["personaname"].presence,
        nickname: player["personaname"].presence,
        urls: {
          "Steam" => player["profileurl"].presence || "https://steamcommunity.com/profiles/#{@steam_id}",
        },
      }
      data[:image] = player["avatarfull"].presence if options.import_avatar
      data
    end

    extra { { "raw_info" => player, "steam_id" => @steam_id } }

    # Ohne Query-String, damit return_to bei Steam und hier identisch ist
    def callback_url
      full_host + script_name + callback_path
    end

    private

    def openid_params
      request.params.select { |key, _| key.start_with?("openid.") }
    end

    # Antworten älter als MAX_NONCE_AGE ablehnen (Schutz vor Wiederverwendung)
    def fresh_nonce?(nonce)
      timestamp = nonce.to_s[/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/]
      return false if timestamp.nil?
      (Time.now.utc - Time.iso8601(timestamp)).abs <= MAX_NONCE_AGE
    rescue ArgumentError
      false
    end

    # Die signierte Antwort direkt bei Steam bestätigen lassen
    def verified_by_steam?(openid)
      body = openid.merge("openid.mode" => "check_authentication")
      response = http_post(STEAM_OPENID_ENDPOINT, body)
      return false unless response.is_a?(Net::HTTPSuccess)
      response.body.to_s.lines.map(&:strip).include?("is_valid:true")
    end

    def player
      @player ||= fetch_player
    end

    def fetch_player
      key = options.api_key.to_s.strip
      return {} if key.empty? || @steam_id.nil?

      uri = URI(PLAYER_SUMMARIES_URL)
      uri.query = URI.encode_www_form(key: key, steamids: @steam_id)
      response = http_get(uri)
      return {} unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig("response", "players", 0) || {}
    rescue StandardError
      # Profilangaben sind optional – die Anmeldung klappt auch ohne
      {}
    end

    def http_get(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: HTTP_TIMEOUT, read_timeout: HTTP_TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
    end

    def http_post(url, form)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: HTTP_TIMEOUT, read_timeout: HTTP_TIMEOUT) do |http|
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(form)
        http.request(request)
      end
    end
  end
end
