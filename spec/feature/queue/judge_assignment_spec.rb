# frozen_string_literal: true

require "rails_helper"

RSpec.feature "Judge assignment to attorney and judge" do
  let(:judge_one) { Judge.new(FactoryBot.create(:user, full_name: "Billie Daniel")) }
  let(:judge_two) { Judge.new(FactoryBot.create(:user, full_name: "Joe Shmoe")) }
  let!(:vacols_user_one) { FactoryBot.create(:staff, :judge_role, user: judge_one.user) }
  let!(:vacols_user_two) { FactoryBot.create(:staff, :judge_role, user: judge_two.user) }
  let!(:judge_one_team) { JudgeTeam.create_for_judge(judge_one.user) }
  let!(:judge_two_team) { JudgeTeam.create_for_judge(judge_two.user) }
  let(:attorney_one) { FactoryBot.create(:user, full_name: "Moe Syzlak") }
  let(:attorney_two) { FactoryBot.create(:user, full_name: "Alice Macgyvertwo") }
  let(:team_attorneys) { [attorney_one, attorney_two] }
  let(:appeal_one) { FactoryBot.create(:appeal) }
  let(:appeal_two) { FactoryBot.create(:appeal) }

  before do
    team_attorneys.each do |attorney|
      create(:staff, :attorney_role, user: attorney)
      OrganizationsUser.add_user_to_organization(attorney, judge_one_team)
    end

    User.authenticate!(user: judge_one.user)
  end

  context "Can assign ama appeal to another judge" do
    let!(:judge_task_one) { create(:ama_judge_task, :in_progress, assigned_to: judge_one.user, appeal: appeal_one) }
    let!(:judge_task_two) { create(:ama_judge_task, :in_progress, assigned_to: judge_one.user, appeal: appeal_two) }

    scenario "submits draft decision" do
      visit "/queue"

      find(".cf-dropdown-trigger", text: COPY::CASE_LIST_TABLE_QUEUE_DROPDOWN_LABEL).click
      expect(page).to have_content(COPY::JUDGE_ASSIGN_DROPDOWN_LINK_LABEL)
      click_on COPY::JUDGE_ASSIGN_DROPDOWN_LINK_LABEL

      expect(page).to have_content("Cases to Assign (2)")
      expect(page).to have_content("Moe Syzlak")
      expect(page).to have_content("Alice Macgyvertwo")

      case_rows = page.find_all("tr[id^='table-row-']")
      expect(case_rows.length).to eq(2)

      step "checks a case and assigns them to another judge" do
        scroll_element_in_to_view(".usa-table-borderless")
        check judge_task_one.id.to_s, allow_label_click: true

        safe_click ".Select"
        click_dropdown(text: "Other")
        safe_click ".dropdown-Other"
        click_dropdown({ text: judge_two.user.full_name }, page.find(".dropdown-Other"))

        click_on "Assign 1 case"
        expect(page).to have_content("Assigned 1 case")
      end
    end
  end

  context "Can move appeals between attorneys" do
    scenario "submits draft decision" do
      judge_task_one = create(:ama_judge_task, :in_progress, assigned_to: judge_one.user, appeal: appeal_one)
      judge_task_two = create(:ama_judge_task, :in_progress, assigned_to: judge_one.user, appeal: appeal_two)

      visit "/queue"

      find(".cf-dropdown-trigger", text: COPY::CASE_LIST_TABLE_QUEUE_DROPDOWN_LABEL).click
      expect(page).to have_content(COPY::JUDGE_ASSIGN_DROPDOWN_LINK_LABEL)
      click_on COPY::JUDGE_ASSIGN_DROPDOWN_LINK_LABEL

      expect(page).to have_content("Cases to Assign (2)")
      expect(page).to have_content("Moe Syzlak")
      expect(page).to have_content("Alice Macgyvertwo")

      case_rows = page.find_all("tr[id^='table-row-']")
      expect(case_rows.length).to eq(2)

      step "checks both cases and assigns them to an attorney" do
        scroll_element_in_to_view(".usa-table-borderless")
        check judge_task_one.id.to_s, allow_label_click: true
        check judge_task_two.id.to_s, allow_label_click: true

        safe_click ".Select"
        click_dropdown(text: attorney_one.full_name)

        click_on "Assign 2 cases"
        expect(page).to have_content("Assigned 2 cases")
      end

      step "navigates to the attorney's case list" do
        click_on "#{attorney_one.full_name} (2)"
        expect(page).to have_content("#{attorney_one.full_name}'s Cases")

        case_rows = page.find_all("tr[id^='table-row-']")
        expect(case_rows.length).to eq(2)
      end

      step "checks one case and assigns it to another attorney" do
        scroll_element_in_to_view(".usa-table-borderless")
        check attorney_one.tasks.first.id.to_s, allow_label_click: true

        safe_click ".Select"
        click_dropdown(text: attorney_two.full_name)

        click_on "Assign 1 case"
        expect(page).to have_content("Assigned 1 case")
      end

      step "navigates to the other attorney's case list" do
        click_on "#{attorney_two.full_name} (1)"
        expect(page).to have_content("#{attorney_two.full_name}'s Cases")

        case_rows = page.find_all("tr[id^='table-row-']")
        expect(case_rows.length).to eq(1)
      end
    end
  end

  context "Can view their queue" do
    let(:appeal) { FactoryBot.create(:appeal) }
    let(:veteran) { appeal.veteran }
    let!(:root_task) { FactoryBot.create(:root_task, appeal: appeal) }

    before do
      create(:ama_judge_task, :in_progress, assigned_to: judge_one.user, appeal: appeal_one)
      create(:ama_judge_task, :in_progress, assigned_to: judge_one.user, appeal: appeal_two)
    end

    context "there's another in-progress JudgeAssignTask" do
      let!(:judge_task) do
        FactoryBot.create(:ama_judge_task, :in_progress, assigned_to: judge_one.user, appeal: appeal, parent: root_task)
      end

      scenario "viewing the assign task queue" do
        visit "/queue"

        find(".cf-dropdown-trigger", text: COPY::CASE_LIST_TABLE_QUEUE_DROPDOWN_LABEL).click
        expect(page).to have_content(COPY::JUDGE_ASSIGN_DROPDOWN_LINK_LABEL)
        click_on COPY::JUDGE_ASSIGN_DROPDOWN_LINK_LABEL

        expect(page).to have_content("Assign 3 Cases")
        expect(page).to have_content("#{veteran.first_name} #{veteran.last_name}")
        expect(page).to have_content(appeal.veteran_file_number)
        expect(page).to have_content("Original")
        expect(page).to have_content(appeal.docket_number)
      end
    end

    context "there's an in-progress JudgeDecisionReviewTask" do
      let!(:judge_review_task) do
        FactoryBot.create(
          :ama_judge_decision_review_task, :in_progress, assigned_to: judge_one.user, appeal: appeal, parent: root_task
        )
      end

      scenario "viewing the review task queue" do
        expect(judge_review_task.status).to eq("in_progress")
        attorney_completed_task = FactoryBot.create(:ama_attorney_task, appeal: appeal, parent: judge_review_task)
        attorney_completed_task.update!(status: Constants.TASK_STATUSES.completed)
        case_review = FactoryBot.create(:attorney_case_review, task_id: attorney_completed_task.id)

        visit "/queue"

        expect(page).to have_content("Review 1 Cases")
        expect(page).to have_content("#{veteran.first_name} #{veteran.last_name}")
        expect(page).to have_content(appeal.veteran_file_number)
        expect(page).to have_content(case_review.document_id)
        expect(page).to have_content("Original")
        expect(page).to have_content(appeal.docket_number)
      end

      scenario "navigating between review and assign task queues" do
        visit "/queue"

        find(".cf-dropdown-trigger", text: COPY::CASE_LIST_TABLE_QUEUE_DROPDOWN_LABEL).click
        expect(page).to have_content(COPY::JUDGE_ASSIGN_DROPDOWN_LINK_LABEL)
        click_on COPY::JUDGE_ASSIGN_DROPDOWN_LINK_LABEL

        expect(page).to have_current_path("/queue/#{judge_one.user.id}/assign")
        expect(page).to have_content("Assign 2 Cases")

        find(".cf-dropdown-trigger", text: COPY::CASE_LIST_TABLE_QUEUE_DROPDOWN_LABEL).click
        expect(page).to have_content(COPY::JUDGE_REVIEW_DROPDOWN_LINK_LABEL)
        click_on COPY::JUDGE_REVIEW_DROPDOWN_LINK_LABEL

        expect(page).to have_current_path("/queue/#{judge_one.user.id}/review")
        expect(page).to have_content("Review 1 Cases")
      end
    end
  end

  describe "Assigning a legacy appeal to an attorney from the case details page" do
    let!(:vacols_case) { FactoryBot.create(:case, staff: vacols_user_one) }
    let!(:appeal) { FactoryBot.create(:legacy_appeal, vacols_case: vacols_case) }
    let!(:decass) { FactoryBot.create(:decass, defolder: vacols_case.bfkey) }

    it "should allow us to assign a case to an attorney from the case details page" do
      visit("/queue/appeals/#{appeal.external_id}")

      click_dropdown(text: Constants.TASK_ACTIONS.ASSIGN_TO_ATTORNEY.label)
      click_dropdown(prompt: "Select a user", text: attorney_one.full_name)
      click_on("Submit")

      expect(page).to have_content("Assigned 1 case")
    end
  end

  describe "Assigning an ama appeal to a judge from the case details page" do
    before do
      create(:ama_judge_task, :in_progress, assigned_to: judge_one.user, appeal: appeal_one)
      create(:ama_judge_task, :in_progress, assigned_to: judge_one.user, appeal: appeal_two)
    end

    it "should allow us to assign an ama appeal to a judge from the case details page" do
      visit("/queue/appeals/#{appeal_one.external_id}")

      click_dropdown(text: Constants.TASK_ACTIONS.ASSIGN_TO_ATTORNEY.label)
      click_dropdown(prompt: "Select a user", text: "Other")
      safe_click ".dropdown-Other"
      click_dropdown({ text: judge_two.user.full_name }, page.find(".dropdown-Other"))

      click_on("Submit")

      expect(page).to have_content("Assigned 1 case")
    end
  end

  describe "requesting cases (automatic case distribution)" do
    before { FeatureToggle.enable!(:automatic_case_distribution) }
    after { FeatureToggle.disable!(:automatic_case_distribution) }

    it "displays an error if the distribution request is invalid" do
      create(:ama_judge_task, :in_progress, assigned_at: 40.days.ago, assigned_to: judge_one.user, appeal: appeal_one)

      visit("/queue/#{judge_one.user.id}/assign")
      click_on("Request more cases")
      find_button("Request more cases")

      expect(page).to have_content("Cases in your queue are waiting to be assigned")
    end

    it "queues the case distribution if the request is valid" do
      create(:ama_judge_task, :in_progress, assigned_at: 10.days.ago, assigned_to: judge_one.user, appeal: appeal_one)

      visit("/queue/#{judge_one.user.id}/assign")
      click_on("Request more cases")

      expect(page).to have_content("Distribution complete")
    end
  end
end
