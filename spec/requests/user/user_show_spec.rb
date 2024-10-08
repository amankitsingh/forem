require "rails_helper"

RSpec.describe "UserShow" do
  let!(:profile) do
    create(
      :profile,
      :with_DEV_info,
      user: create(:user, :without_profile),
    )
  end
  let(:user) { profile.user }

  describe "GET /:slug (user)" do
    before do
      FeatureFlag.add(:subscriber_icon)
      FeatureFlag.enable(:subscriber_icon)
    end

    it "returns a 200 status when navigating to the user's page" do
      get user.path
      expect(response).to have_http_status(:ok)
    end

    it "renders the proper JSON-LD for a user" do
      user.setting.update(display_email_on_profile: true)
      get user.path
      text = Nokogiri::HTML(response.body).at('script[type="application/ld+json"]').text
      response_json = JSON.parse(text)
      expect(response_json).to include(
        "@context" => "http://schema.org",
        "@type" => "Person",
        "mainEntityOfPage" => {
          "@type" => "WebPage",
          "@id" => URL.user(user)
        },
        "url" => URL.user(user),
        "sameAs" => [
          "https://twitter.com/#{user.twitter_username}",
          "https://github.com/#{user.github_username}",
          "http://example.com",
        ],
        "image" => user.profile_image_url_for(length: 320),
        "name" => user.name,
        "email" => user.email,
        "description" => user.tag_line,
      )
    end

    it "includes a subscription icon if user is subscribed" do
      user.add_role("base_subscriber")
      get user.path
      expect(response.body).to include('class="subscription-icon"')
    end

    it "does not include a subscription icon if user is not subscribed" do
      get user.path
      expect(response.body).not_to include('class="subscription-icon"')
    end

    it "does not render a key if no value is given" do
      incomplete_user = create(:user)
      get incomplete_user.path
      text = Nokogiri::HTML(response.body).at('script[type="application/ld+json"]').text
      response_json = JSON.parse(text)
      expect(response_json).not_to include("worksFor")
      expect(response_json.value?(nil)).to be(false)
      expect(response_json.value?("")).to be(false)
    end

    context "when user signed in" do
      before do
        sign_in user
        get user.path
      end

      it "does not render json ld" do
        expect(response.body).not_to include "application/ld+json"
      end
    end

    context "when user not signed in" do
      before do
        get user.path
      end

      it "does not render json ld" do
        expect(response.body).to include "application/ld+json"
      end
    end

    context "when user not signed in but internal nav triggered" do
      before do
        get "#{user.path}?i=i"
      end

      it "does not render json ld" do
        expect(response.body).not_to include "application/ld+json"
      end
    end
  end

  describe "GET /users/ID.json" do
    it "404s when user not found" do
      get user_path("NaN", format: "json")
      expect(response).to have_http_status(:not_found)
    end

    context "when user not signed in" do
      it "does not include 'suspended'" do
        get user_path(user, format: "json")
        parsed = response.parsed_body
        expect(parsed.keys).to match_array(%w[id username])
      end
    end

    context "when user **is** signed in **and** trusted" do
      let(:trusted) { create(:user, :trusted) }

      before do
        sign_in trusted

        get user.path
      end

      it "**does** include 'suspended'" do
        get user_path(user, format: "json")
        parsed = response.parsed_body
        expect(parsed.keys).to match_array(%w[id username suspended])
      end
    end
  end
end
