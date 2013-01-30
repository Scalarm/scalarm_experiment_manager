class String

  def with_delimeters
    string_copy = self.reverse

    len = 3; num_of_comas = 0;
    while((len + num_of_comas <= string_copy.size) and string_copy.size > 3) do
      string_copy.insert(len, ",")
      num_of_comas = 1; len += 4
    end

    string_copy.reverse
  end

end