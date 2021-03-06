# frozen_string_literal: true

require "rails_helper"

RSpec.feature "Hearings tasks workflows" do
  let(:user) { FactoryBot.create(:user) }

  before do
    OrganizationsUser.add_user_to_organization(user, HearingAdmin.singleton)
    User.authenticate!(user: user)
  end

  describe "Postponing a NoShowHearingTask" do
    let(:appeal) { FactoryBot.create(:appeal, :hearing_docket) }
    let(:root_task) { FactoryBot.create(:root_task, appeal: appeal) }
    let(:distribution_task) { FactoryBot.create(:distribution_task, appeal: appeal, parent: root_task) }
    let(:parent_hearing_task) { FactoryBot.create(:hearing_task, parent: distribution_task, appeal: appeal) }
    let!(:completed_scheduling_task) do
      FactoryBot.create(:schedule_hearing_task, :completed, parent: parent_hearing_task, appeal: appeal)
    end
    let(:disposition_task) { FactoryBot.create(:disposition_task, parent: parent_hearing_task, appeal: appeal) }
    let!(:no_show_hearing_task) do
      FactoryBot.create(:no_show_hearing_task, parent: disposition_task, appeal: appeal)
    end

    it "closes current branch of task tree and starts a new one" do
      expect(distribution_task.children.count).to eq(1)
      expect(distribution_task.children.active.count).to eq(1)

      visit("/queue/appeals/#{appeal.uuid}")
      click_dropdown(text: Constants.TASK_ACTIONS.RESCHEDULE_NO_SHOW_HEARING.label)
      click_on(COPY::MODAL_SUBMIT_BUTTON)

      expect(page).to have_content("Success")

      expect(distribution_task.children.count).to eq(2)
      expect(distribution_task.children.active.count).to eq(1)

      new_parent_hearing_task = distribution_task.children.active.first
      expect(new_parent_hearing_task).to be_a(HearingTask)
      expect(new_parent_hearing_task.children.first).to be_a(ScheduleHearingTask)

      expect(distribution_task.ready_for_distribution?).to eq(false)
    end
  end

  describe "Completing a NoShowHearingTask" do
    def mark_complete_and_verify_status(appeal, page, task)
      visit("/queue/appeals/#{appeal.external_id}")
      click_dropdown(text: Constants.TASK_ACTIONS.MARK_NO_SHOW_HEARING_COMPLETE.label)
      click_on(COPY::MARK_TASK_COMPLETE_BUTTON)

      expect(page).to have_content(format(COPY::MARK_TASK_COMPLETE_CONFIRMATION, appeal.veteran_full_name))

      expect(task.reload.status).to eq(Constants.TASK_STATUSES.completed)
    end

    let(:appeal) { FactoryBot.create(:appeal, :hearing_docket) }
    let(:root_task) { FactoryBot.create(:root_task, appeal: appeal) }
    let(:distribution_task) { FactoryBot.create(:distribution_task, appeal: appeal, parent: root_task) }
    let(:parent_hearing_task) { FactoryBot.create(:hearing_task, parent: hearing_task_parent, appeal: appeal) }
    let!(:completed_scheduling_task) do
      FactoryBot.create(:schedule_hearing_task, :completed, parent: parent_hearing_task, appeal: appeal)
    end
    let(:disposition_task) { FactoryBot.create(:disposition_task, parent: parent_hearing_task, appeal: appeal) }
    let!(:no_show_hearing_task) do
      FactoryBot.create(:no_show_hearing_task, parent: disposition_task, appeal: appeal)
    end

    context "when the appeal is a LegacyAppeal" do
      let(:appeal) { FactoryBot.create(:legacy_appeal, vacols_case: FactoryBot.create(:case)) }
      let(:hearing_task_parent) { root_task }

      context "when the appellant is represented by a VSO" do
        before do
          FactoryBot.create(:vso)
          allow_any_instance_of(LegacyAppeal).to receive(:representatives) { Representative.all }
        end

        it "marks all Caseflow tasks complete and sets the VACOLS location correctly" do
          caseflow_task_count_before = Task.count

          mark_complete_and_verify_status(appeal, page, no_show_hearing_task)

          expect(Task.count).to eq(caseflow_task_count_before)
          expect(Task.active.where.not(type: RootTask.name).count).to eq(0)

          # Re-find the appeal so we re-fetch information from VACOLS.
          refreshed_appeal = LegacyAppeal.find(appeal.id)
          expect(refreshed_appeal.location_code).to eq(LegacyAppeal::LOCATION_CODES[:service_organization])
        end
      end

      context "when the appellant is not represented by a VSO" do
        it "marks all Caseflow tasks complete and sets the VACOLS location correctly" do
          caseflow_task_count_before = Task.count

          mark_complete_and_verify_status(appeal, page, no_show_hearing_task)

          expect(Task.count).to eq(caseflow_task_count_before)
          expect(Task.active.where.not(type: RootTask.name).count).to eq(0)

          # Re-find the appeal so we re-fetch information from VACOLS.
          refreshed_appeal = LegacyAppeal.find(appeal.id)
          expect(refreshed_appeal.location_code).to eq(LegacyAppeal::LOCATION_CODES[:case_storage])
        end
      end
    end

    context "when the appeal is an AMA Appeal" do
      let(:hearing_task_parent) { distribution_task }

      context "when the appellant is represented by a VSO" do
        before do
          FactoryBot.create(:vso)
          allow_any_instance_of(Appeal).to receive(:representatives) { Representative.all }
        end

        context "when the VSO is not supposed to write an IHP for this appeal" do
          before { allow_any_instance_of(Representative).to receive(:should_write_ihp?) { false } }

          it "marks the case ready for distribution" do
            mark_complete_and_verify_status(appeal, page, no_show_hearing_task)

            # DispositionTask has been closed and no IHP tasks have been created for this appeal.
            expect(parent_hearing_task.reload.children.active.count).to eq(0)
            expect(InformalHearingPresentationTask.count).to eq(0)

            expect(distribution_task.reload.ready_for_distribution?).to eq(true)
          end
        end

        context "when the VSO is supposed to write an IHP for this appeal" do
          before { allow_any_instance_of(Representative).to receive(:should_write_ihp?) { true } }

          it "creates an IHP task as a child of the HearingTask" do
            mark_complete_and_verify_status(appeal, page, no_show_hearing_task)

            # DispositionTask has been closed but IHP task has been created for this appeal.
            expect(parent_hearing_task.parent.reload.children.active.count).to eq(1)
            expect(parent_hearing_task.parent.children.active.first).to be_a(InformalHearingPresentationTask)

            expect(distribution_task.reload.ready_for_distribution?).to eq(false)
          end
        end
      end

      context "when the appellant is not represented by a VSO" do
        it "marks the case ready for distribution" do
          mark_complete_and_verify_status(appeal, page, no_show_hearing_task)

          # DispositionTask has been closed and no IHP tasks have been created for this appeal.
          expect(parent_hearing_task.reload.children.active.count).to eq(0)
          expect(InformalHearingPresentationTask.count).to eq(0)

          expect(distribution_task.reload.ready_for_distribution?).to eq(true)
        end
      end
    end
  end
end
