module GenericErrors
  class ControllerError < StandardError
    attr_reader :error_code
    def initialize(error_code, message)
      super(message)
      @error_code = error_code
    end
  end

  class ValidationError < StandardError; end
end