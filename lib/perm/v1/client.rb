module CF::Perm::V1
  class Client
    attr_accessor :uri

    def initialize(uri)
      @uri = uri
    end

    def assign_role(actor, role, context)
      return nil
    end
  end
end
