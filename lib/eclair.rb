# frozen_string_literal: true
module Eclair
end

require "eclair/providers/ec2"

# require "curses"
# require "zlib"
# require "aws-sdk"
# require "string_scorer"
# require "pry"
# require "eclair/item"
# require "eclair/helpers/benchmark_helper"
# require "eclair/helpers/common_helper"
# require "eclair/helpers/aws_helper"
# require "eclair/config"
# require "eclair/version"
# require "eclair/less_viewer"
# require "eclair/grid"
# require "eclair/column"
# require "eclair/cell"
# require "eclair/group"
# require "eclair/instance"
# require "eclair/console"
# require "eclair/color"

require 'logger'

module Eclair
  class << self
    def logger
      @logger ||= begin
                    logger = Logger.new($stdout)
                    # 설정 파일(Eclair.config)이 로드된 후에 레벨을 설정해야 함
                    # 따라서 초기에는 기본 레벨로 설정하거나, 설정 로드 후 레벨을 지정해야 함
                    logger.level = Logger::INFO
                    logger.formatter = proc do |severity, datetime, progname, msg|
                      formatted_time = datetime.strftime("%Y-%m-%d %H:%M:%S")
                      "[#{formatted_time}] #{severity}: #{msg}\n"
                    end
                    logger
                  end
    end
  end
end
