require 'rails_helper'
require 'fileutils'

RSpec.describe AfterFinishHook do
  describe '#call' do
    context 'when the run has a result file attached' do
      it 'transitions to the succeeded state' do
        run = create(:run, :ongoing, :with_result)
        expect(run.state).to eq('ongoing')

        AfterFinishHook.new(run: run).call

        expect(run.state).to eq('succeeded')
      end
    end

    context 'when the run has no result file attached' do
      it 'sets the outcome to failure' do
        run = create(:run, :ongoing)
        expect(run.state).to eq('ongoing')

        AfterFinishHook.new(run: run).call

        expect(run.state).to eq('failed')
      end
    end

    context 'when a log file exists' do
      it 'uploads the log file' do
        run = create(:run)
        FileUtils.touch(
          Rails.root.join('tmp', run.local_log_path),
        )
        expect(run.log_file).not_to be_attached

        AfterFinishHook.new(run: run).call

        expect(run.log_file).to be_attached
      end
    end

    context 'when there is no log file' do
      it 'does not attach the log file' do
        run = create(:run)
        expect(run.log_file).not_to be_attached

        AfterFinishHook.new(run: run).call

        expect(run.log_file).not_to be_attached
      end
    end
  end
end
