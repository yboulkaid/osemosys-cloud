module Osemosys
  module Solvers
    class Cbc
      def initialize(local_model_path:, local_data_path:, logger: Config.logger, run:)
        @local_data_path = local_data_path
        @local_model_path = local_model_path
        @logger = logger
        @run = run
      end

      def call
        if preprocess_data_file?
          run.transition_to!(:preprocessing_data)
          preprocess_data_file
        end
        run.transition_to!(:generating_matrix)
        generate_input_file
        run.transition_to!(:finding_solution)
        find_solution
        zip_output
        if postprocess_results?
          run.transition_to!(:postprocessing)
          postprocess_results
        end
        print_summary

        zipped_output_path
      end

      private

      def preprocess_data_file?
        run.pre_process?
      end

      def postprocess_results?
        run.post_process?
      end

      attr_reader :local_data_path, :local_model_path, :logger, :run

      def preprocess_data_file
        Commands::PreprocessDataFile.new(
          local_data_path: local_data_path,
          preprocessed_data_path: preprocessed_data_path,
          logger: logger,
        ).call
      end

      def generate_input_file
        input_file = preprocess_data_file? ? preprocessed_data_path : local_data_path
        Commands::GenerateInputFile.new(
          local_model_path: local_model_path,
          local_data_path: input_file,
          lp_path: lp_path,
          logger: logger,
        ).call
      end

      def find_solution
        Commands::FindSolution.new(
          lp_path: lp_path,
          output_path: output_path,
          logger: logger,
        ).call
      end

      def zip_output
        Commands::Zip.new(
          source: output_path,
          destination: zipped_output_path,
          logger: logger,
        ).call
      end

      def postprocess_results
        Commands::PostProcessResultFiles.new(
          preprocessed_data_path: preprocessed_data_path,
          solution_file_path: output_path,
          logger: logger,
        ).call

        Commands::ZipFolder.new(
          folder: 'csv/',
          destination: zipped_csv_path,
          logger: logger,
        ).call

        run.csv_results.attach(
          io: File.open(zipped_csv_path),
          filename: File.basename(zipped_csv_path),
        )
      end

      def print_summary
        logger.info 'Model solved!'
        logger.info ''
        logger.info "run_id: #{Config.run_id}"
      end

      def lp_path
        "./data/input_#{Config.run_id}.lp"
      end

      def output_path
        "./data/output_#{Config.run_id}.txt"
      end

      def zipped_output_path
        "./data/output_#{Config.run_id}.zip"
      end

      def zipped_csv_path
        "./data/csv_#{Config.run_id}.zip"
      end

      def preprocessed_data_path
        "#{local_data_path}.pre"
      end
    end
  end
end
