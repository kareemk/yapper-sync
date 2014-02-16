class Object
  def as_json
    self
  end
end

class Hash
  def as_json
    hash = self.class.new
    self.each { |k,v| hash[k] = v.as_json }
    hash
  end
end

class NSDictionary
  def as_json
    to_hash.as_json
  end
end

class Array
  def as_json
    self.map { |v| v.as_json }
  end
end

class NSArray
  def as_json
    self.map { |v| v.as_json }
  end
end

class Time
  def as_json
    self.to_iso8601
  end
end
