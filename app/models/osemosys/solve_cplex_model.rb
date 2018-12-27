module Osemosys
  class SolveCplexModel
    def initialize(s3_data_key:, s3_model_key:, logger: Config.logger)
      @s3_model_key = s3_model_key
      @s3_data_key = s3_data_key
      @logger = logger
    end

    def call
      download_files_from_s3
      generate_input_file
      solve_model
      gzip_output
      print_summary
      output_file.file
    end

    private

    attr_reader :s3_model_key, :s3_data_key, :logger

    def download_files_from_s3
      logger.info 'Downloading input files...'

      logger.info 'Downloading model file...'
      s3_model_object.download_file(local_model_file_path)

      logger.info 'Downloading data file...'
      s3_data_object.download_file(local_data_file_path)
    end

    def generate_input_file
      logger.info 'Generating input file'
      tty_command.run(glpsol_command)
    end

    def solve_model
      logger.info 'Solving the model'
      tty_command.run(cplex_command)
    end

    def gzip_output
      logger.info 'Gzipping the output'
      tty_command.run(gzip_command)
    end

    def print_summary
      logger.info 'Model solved!'
      logger.info ''
      logger.info "run_id: #{Config.run_id}"
    end

    def glpsol_command
      %(
      glpsol -m #{local_model_file_path}
             -d #{local_data_file_path}
             --wlp #{cplex_input_file}
      ).delete("\n")
    end

    def gzip_command
      "gzip -f #{output_path}"
    end

    def cplex_command
      %(
        cplex -c "read #{cplex_input_file}" "optimize" "write #{output_path}"
      )
    end

    def tty_command
      @tty_command ||= TTY::Command.new(output: logger, color: false)
    end

    def s3_data_object
      @s3_data_object ||= s3.bucket(bucket).object(s3_data_key)
    end

    def s3_model_object
      @s3_model_object ||= s3.bucket(bucket).object(s3_model_key)
    end

    # TODO: Extract these
    def local_data_file_path
      "/tmp/data_#{Config.run_id}.txt"
    end

    def local_model_file_path
      "/tmp/model_#{Config.run_id}.txt"
    end

    def cplex_input_file
      './input.lp'
    end

    def output_path
      './output.sol'
    end

    def gzipped_output_path
      './output.sol.gz'
    end

    def output_file
      OutputFile.new(gzipped_output_path)
    end

    def bucket
      Config.s3_bucket
    end

    def s3
      @s3 ||= Aws::S3::Resource.new(region: 'eu-west-1')
    end
  end
end
