# frozen_string_literal: true

describe TrackVeteranTask do
  let(:vso) { FactoryBot.create(:vso) }
  let(:root_task) { FactoryBot.create(:root_task) }
  let(:tracking_task) do
    FactoryBot.create(
      :track_veteran_task,
      parent: root_task,
      appeal: root_task.appeal,
      assigned_to: vso
    )
  end

  describe ".create!" do
    it "sets the status of the task to in_progress" do
      task = TrackVeteranTask.create(parent: root_task, appeal: root_task.appeal, assigned_to: vso)
      expect(task.status).to eq(Constants.TASK_STATUSES.in_progress)
    end
  end

  describe ".available_actions" do
    it "should never have available_actions" do
      expect(tracking_task.available_actions(vso)).to eq([])
    end
  end

  describe ".hide_from_queue_table_view" do
    it "should always be hidden from queue table view" do
      expect(tracking_task.hide_from_queue_table_view).to eq(true)
    end
  end

  describe ".hide_from_case_timeline" do
    it "should always be hidden from case timeline" do
      expect(tracking_task.hide_from_case_timeline).to eq(true)
    end
  end

  describe ".hide_from_task_snapshot" do
    it "should always be hidden from task snapshot" do
      expect(tracking_task.hide_from_case_timeline).to eq(true)
    end
  end

  describe ".sync_tracking_tasks" do
    let!(:appeal) { FactoryBot.create(:appeal) }
    let!(:root_task) { FactoryBot.create(:root_task, appeal: appeal) }

    subject { TrackVeteranTask.sync_tracking_tasks(appeal) }

    context "When former represenative VSO is assigned non-Tracking tasks" do
      let!(:old_vso) { FactoryBot.create(:vso, name: "Remember Korea") }
      let!(:new_vso) { FactoryBot.create(:vso) }
      let!(:root_task) { FactoryBot.create(:root_task, appeal: appeal) }

      let!(:ihp_org_task) do
        FactoryBot.create(:informal_hearing_presentation_task, appeal: appeal, assigned_to: old_vso)
      end
      let!(:tracking_task) do
        FactoryBot.create(
          :track_veteran_task,
          parent: root_task,
          appeal: root_task.appeal,
          assigned_to: old_vso
        )
      end

      before { allow_any_instance_of(Appeal).to receive(:representatives).and_return([new_vso]) }

      it "cancels all tasks of former VSO" do
        subject
        expect(ihp_org_task.reload.status).to eq(Constants.TASK_STATUSES.cancelled)
      end

      it "makes duplicates of active tasks for new representation" do
        expect(new_vso.tasks.count).to eq(0)
        expect(subject).to eq([1, 2])
        expect(new_vso.tasks.count).to eq(2)
      end
    end
    context "when the appeal has no VSOs" do
      before { allow_any_instance_of(Appeal).to receive(:representatives).and_return([]) }

      context "when there are no existing TrackVeteranTasks" do
        it "does not create or cancel any TrackVeteranTasks" do
          task_count_before = TrackVeteranTask.count

          expect(subject).to eq([0, 0])
          expect(TrackVeteranTask.count).to eq(task_count_before)
        end
      end

      context "when there is an existing open TrackVeteranTasks" do
        let(:vso) { FactoryBot.create(:vso) }
        let!(:tracking_task) { FactoryBot.create(:track_veteran_task, appeal: appeal, assigned_to: vso) }

        it "cancels old TrackVeteranTask, does not create any new tasks" do
          active_task_count_before = TrackVeteranTask.active.count

          expect(subject).to eq([0, 1])
          expect(TrackVeteranTask.active.count).to eq(active_task_count_before - 1)
        end
      end
    end

    context "when the appeal has two VSOs" do
      let(:representing_vsos) { FactoryBot.create_list(:vso, 2) }
      before { allow_any_instance_of(Appeal).to receive(:representatives).and_return(representing_vsos) }

      context "when there are no existing TrackVeteranTasks" do
        it "creates 2 new TrackVeteranTasks and 2 IHP Tasks" do
          task_count_before = TrackVeteranTask.count

          expect(subject).to eq([2, 0])
          expect(TrackVeteranTask.count).to eq(task_count_before + 2)
        end
      end

      context "when there is an existing open TrackVeteranTasks for a different VSO" do
        before do
          FactoryBot.create(:track_veteran_task, appeal: appeal, assigned_to: FactoryBot.create(:vso))
        end

        it "cancels old TrackVeteranTask, creates 2 new TrackVeteran and 2 new IHP tasks" do
          expect(subject).to eq([2, 1])
        end
      end

      context "when there are already TrackVeteranTasks for both VSOs" do
        before do
          representing_vsos.each do |vso|
            FactoryBot.create(:track_veteran_task, appeal: appeal, assigned_to: vso)
          end
        end

        it "does not create or cancel any TrackVeteranTasks" do
          task_count_before = TrackVeteranTask.count

          expect(subject).to eq([0, 0])
          expect(TrackVeteranTask.count).to eq(task_count_before)
        end
      end
    end
  end
end
