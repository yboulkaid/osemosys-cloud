class Run < ApplicationRecord
  extend Statesman::Adapters::ActiveRecordQueries[transition_class: RunTransition, initial_state: :new]
  delegate :current_state, :history, :transition_to, :transition_to!,
    :can_transition_to?, :last_transition, to: :state_machine

  has_many :run_transitions, autosave: false
  has_one :ec2_instance, class_name: 'Ec2::Instance'

  belongs_to :user
  has_one_attached :model_file
  has_one_attached :data_file
  has_one_attached :log_file
  has_one :run_result

  validates :name, presence: true
  validates :model_file, attached: true
  validates :data_file, attached: true

  validate :only_postprocess_preprocessed_runs

  delegate :result_file, :csv_results, to: :run_result, allow_nil: true

  def solving_time
    transitions = history

    return unless transitions.last&.final?

    transitions.last.created_at - transitions.first.created_at
  end

  def local_log_path
    "/tmp/run-#{id}.log"
  end

  def can_be_queued?
    can_transition_to? :queued
  end

  def can_be_stopped?
    can_transition_to? :failed
  end

  def in_progress?
    return false unless last_transition.present?

    !last_transition.final?
  end

  def state_machine
    @state_machine ||= StateMachine.new(
      self, transition_class: RunTransition
    )
  end

  def humanized_status
    Run::ToHumanState.call(state_slug: state)
  end

  private

  def only_postprocess_preprocessed_runs
    if post_process.present? && pre_process.blank?
      errors.add(:post_process, 'can only be enabled if pre-processing is enabled')
    end
  end
end
