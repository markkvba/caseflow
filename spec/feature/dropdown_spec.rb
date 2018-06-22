require "rails_helper"

RSpec.feature "Dropdown" do
  before do
    FeatureToggle.enable!(:test_facols)
  end

  after do
    FeatureToggle.disable!(:test_facols)
  end

  let!(:current_user) { User.authenticate! }
  let(:appeal) { create(:legacy_appeal, vacols_case: create(:case)) }

  scenario "Dropdown works on both erb and react pages" do
    User.authenticate!

    visit "certifications/new/#{appeal.vacols_id}"
    click_on "DSUSER (DSUSER)"
    expect(page).to have_content("Sign Out")

    visit "dispatch/establish-claim"
    click_on "Menu"
    expect(page).to have_content("Help")
  end
end
