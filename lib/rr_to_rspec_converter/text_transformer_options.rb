class TextTransformerOptions
  attr_accessor :file_path
  attr_writer :quiet

  def initialize
    @file_path = nil
    @quiet = false
  end

  def quiet?
    @quiet
  end
end
